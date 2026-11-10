package com.localmail.local_mail_client

import android.accounts.Account
import android.content.Intent
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.AuthorizationResult
import com.google.android.gms.auth.api.identity.ClearTokenRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Scope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Gmail authorization bridge backed by Google Play Services AuthorizationClient.
 *
 * The device only receives short-lived access tokens. There is deliberately no
 * client secret or fabricated refresh token: expiry is renewed by calling
 * authorize() again, silently unless the user explicitly starts a login.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.localmail.local_mail_client/google_auth"
    private val authorizeRequestCode = 4817

    private var authorizationInFlight = false
    private var pendingResult: MethodChannel.Result? = null
    private var pendingEmail: String? = null
    private var pendingScopes: List<String> = emptyList()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "authorize" -> handleAuthorize(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleAuthorize(call: MethodCall, result: MethodChannel.Result) {
        // Guard the whole async lifetime, not just the interactive resolution:
        // a second call while authorize() is still resolving would otherwise
        // overwrite pendingResult.
        if (authorizationInFlight) {
            result.error(
                "authorization_in_progress",
                "Another Google authorization is running.",
                null,
            )
            return
        }
        val email = call.argument<String>("email")?.trim().orEmpty()
        if (email.isEmpty()) {
            result.error("invalid_argument", "A Google account email is required.", null)
            return
        }
        val scopes = (call.argument<List<*>>("scopes") ?: emptyList<Any>())
            .map { it.toString() }
        val interactive = call.argument<Boolean>("interactive") ?: true
        val previousToken = call.argument<String>("previousAccessToken")

        val availability = GoogleApiAvailability.getInstance()
            .isGooglePlayServicesAvailable(this)
        if (availability != ConnectionResult.SUCCESS) {
            result.error(
                "gms_unavailable",
                "Google Play services is unavailable (status $availability).",
                null,
            )
            return
        }

        authorizationInFlight = true
        runAuthorization(email, scopes, interactive, previousToken, result)
    }

    private fun runAuthorization(
        email: String,
        scopes: List<String>,
        interactive: Boolean,
        previousToken: String?,
        result: MethodChannel.Result,
    ) {
        val authClient = Identity.getAuthorizationClient(this)
        val request = AuthorizationRequest.builder()
            .setRequestedScopes(scopes.map { Scope(it) })
            .setAccount(Account(email, "com.google"))
            .build()

        val authorize = {
            authClient.authorize(request)
                .addOnSuccessListener { authorizationResult ->
                    handleAuthorizationResult(
                        email,
                        scopes,
                        interactive,
                        authorizationResult,
                        result,
                    )
                }
                .addOnFailureListener { error ->
                    failAuthorization(result, error, "authorize_call")
                }
        }

        if (previousToken.isNullOrEmpty()) {
            authorize()
        } else {
            // Force a fresh token instead of assuming the cached token's expiry.
            authClient.clearToken(
                ClearTokenRequest.builder().setToken(previousToken).build(),
            ).addOnCompleteListener {
                authorize()
            }
        }
    }

    private fun handleAuthorizationResult(
        email: String,
        scopes: List<String>,
        interactive: Boolean,
        authorizationResult: AuthorizationResult,
        result: MethodChannel.Result,
    ) {
        if (authorizationResult.hasResolution()) {
            if (!interactive) {
                finishError(
                    result,
                    "interaction_required",
                    "Google authorization needs user interaction.",
                    mapOf("stage" to "interactive_resolution"),
                )
                return
            }
            pendingResult = result
            pendingEmail = email
            pendingScopes = scopes
            try {
                startIntentSenderForResult(
                    authorizationResult.pendingIntent!!.intentSender,
                    authorizeRequestCode,
                    null,
                    0,
                    0,
                    0,
                )
            } catch (error: Exception) {
                failAuthorization(result, error, "start_resolution")
            }
            return
        }

        val accessToken = authorizationResult.accessToken
        if (accessToken.isNullOrEmpty()) {
            finishError(
                result,
                "auth_failed",
                "Google returned no access token.",
                mapOf("stage" to "authorization_result"),
            )
            return
        }
        finishSuccess(result, accessToken, authorizationResult.grantedScopes)
    }

    @Deprecated("FlutterActivity still dispatches activity results here.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != authorizeRequestCode) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingResult
        val email = pendingEmail
        val scopes = pendingScopes
        clearPending()
        if (result == null) {
            authorizationInFlight = false
            return
        }

        // Google's own ActivityResult sample parses any non-null intent without
        // checking resultCode first: configuration errors arrive as an
        // ApiException (for example DEVELOPER_ERROR) and must not be reported as
        // a user cancellation.
        if (data == null) {
            finishError(
                result,
                "no_result",
                "Google authorization did not finish: no result was returned. Please retry.",
                mapOf("stage" to "activity_result", "resultCode" to resultCode),
            )
            return
        }
        try {
            val authorizationResult = Identity.getAuthorizationClient(this)
                .getAuthorizationResultFromIntent(data)
            val accessToken = authorizationResult.accessToken
            if (!accessToken.isNullOrEmpty()) {
                finishSuccess(result, accessToken, authorizationResult.grantedScopes)
            } else if (email != null) {
                // Consent was granted; one silent pass now yields the token.
                // Keep authorizationInFlight=true for this second request.
                runAuthorization(email, scopes, false, null, result)
            } else {
                finishError(
                    result,
                    "auth_failed",
                    "Google returned no access token.",
                    mapOf("stage" to "activity_result"),
                )
            }
        } catch (error: Exception) {
            failAuthorization(result, error, "activity_result", resultCode)
        }
    }

    private fun finishSuccess(
        result: MethodChannel.Result,
        accessToken: String,
        grantedScopes: List<String>,
    ) {
        endAuthorization()
        result.success(
            mapOf(
                "accessToken" to accessToken,
                "expiresIn" to 3300,
                "grantedScopes" to grantedScopes,
            ),
        )
    }

    private fun finishError(
        result: MethodChannel.Result,
        code: String,
        message: String,
        details: Map<String, Any?>? = null,
    ) {
        endAuthorization()
        result.error(code, message, details)
    }

    /**
     * Sends only non-sensitive diagnostics: native status code, stage and the
     * Activity result code. Never include tokens, the account email, an Intent
     * dump, or the raw exception text.
     */
    private fun failAuthorization(
        result: MethodChannel.Result,
        error: Exception,
        stage: String,
        resultCode: Int? = null,
    ) {
        val statusCode = (error as? ApiException)?.statusCode
        val code = errorCode(error)
        val details = mutableMapOf<String, Any?>("stage" to stage)
        if (statusCode != null) details["statusCode"] = statusCode
        if (resultCode != null) details["resultCode"] = resultCode
        finishError(result, code, friendlyMessage(code, statusCode), details)
    }

    private fun friendlyMessage(code: String, statusCode: Int?): String {
        val suffix = statusCode?.let { " (status $it)" } ?: ""
        return when (code) {
            "developer_error" ->
                "Google authorization is not configured for this app$suffix. " +
                    "Register the Android OAuth client for the package and SHA-1."
            "network_error", "timeout" ->
                "Network or Google Play services is temporarily unavailable$suffix. " +
                    "Check the connection and retry."
            "cancelled" -> "Google authorization was cancelled or not completed$suffix."
            "sign_in_required" ->
                "The Google account needs to sign in again$suffix."
            else -> "Google authorization failed$suffix. Please retry."
        }
    }

    private fun errorCode(error: Exception): String {
        return when ((error as? ApiException)?.statusCode) {
            CommonStatusCodes.DEVELOPER_ERROR -> "developer_error"
            CommonStatusCodes.SIGN_IN_REQUIRED -> "sign_in_required"
            CommonStatusCodes.CANCELED -> "cancelled"
            CommonStatusCodes.NETWORK_ERROR -> "network_error"
            CommonStatusCodes.TIMEOUT -> "timeout"
            else -> "auth_failed"
        }
    }

    private fun clearPending() {
        pendingResult = null
        pendingEmail = null
        pendingScopes = emptyList()
    }

    private fun endAuthorization() {
        clearPending()
        authorizationInFlight = false
    }

    override fun onDestroy() {
        val result = pendingResult
        if (result != null) {
            // An Activity teardown is not a user cancellation; keep it separate
            // so the UI does not blame the user.
            finishError(
                result,
                "interrupted",
                "Google authorization was interrupted because the screen closed. Please retry.",
                mapOf("stage" to "activity_destroyed"),
            )
        }
        super.onDestroy()
    }
}
