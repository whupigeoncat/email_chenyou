package com.localmail.local_mail_client

import android.accounts.Account
import android.app.Activity
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
                    failAuthorization(result, error, "Google authorization failed.")
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
                failAuthorization(result, error, "Unable to start Google sign-in.")
            }
            return
        }

        val accessToken = authorizationResult.accessToken
        if (accessToken.isNullOrEmpty()) {
            finishError(result, "auth_failed", "Google returned no access token.")
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

        if (resultCode != Activity.RESULT_OK || data == null) {
            finishError(result, "cancelled", "The user cancelled Google authorization.")
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
                finishError(result, "auth_failed", "Google returned no access token.")
            }
        } catch (error: ApiException) {
            failAuthorization(result, error, "Unable to read Google authorization result.")
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
    ) {
        endAuthorization()
        result.error(code, message, null)
    }

    private fun failAuthorization(
        result: MethodChannel.Result,
        error: Exception,
        fallback: String,
    ) {
        finishError(result, errorCode(error), error.message ?: fallback)
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
            finishError(result, "cancelled", "Google authorization was interrupted.")
        }
        super.onDestroy()
    }
}
