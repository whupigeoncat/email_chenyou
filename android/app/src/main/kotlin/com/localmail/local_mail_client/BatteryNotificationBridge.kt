package com.localmail.local_mail_client

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * UI and headless MethodChannel for notification settings, scheduling,
 * foreground leases and notification presentation.
 */
class BatteryNotificationBridge(
    private val context: Context,
    private val activity: Activity?,
    private val isCancelledProvider: () -> Boolean = { false },
    private val onBackgroundFinished: (() -> Unit)? = null,
) {
    companion object {
        const val CHANNEL_NAME = "com.localmail.local_mail_client/battery_notifications"
        private const val PERMISSION_REQUEST_CODE = 4818
    }

    private var channel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var detached = false
    private var heldForegroundLeases = 0

    fun attach(engine: FlutterEngine) {
        detached = false
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler { call, result ->
            if (!handle(call, result)) result.notImplemented()
        }
    }

    fun detach() {
        detached = true
        channel?.setMethodCallHandler(null)
        channel = null
        releaseHeldForegroundLeases()
        pendingPermissionResult?.error(
            "interrupted",
            "Notification permission request was interrupted.",
            null,
        )
        pendingPermissionResult = null
    }

    /** Wakes a running UI to the inbox; the pending flag covers cold starts. */
    fun notifyOpenInbox() {
        try {
            channel?.invokeMethod("openInbox", null)
        } catch (_: Throwable) {
            // UI isolate is not ready; consumePendingInboxOpen handles it.
        }
    }

    /** Returns false when the method is not owned by this bridge. */
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "getSettings" -> result.success(BatteryNotificationScheduler.settings(context))
            "setIntervalMinutes" -> {
                val minutes = (call.argument<Number>("minutes"))?.toInt() ?: 30
                result.success(
                    BatteryNotificationScheduler.setIntervalMinutes(context, minutes),
                )
            }
            "requestNotificationPermission" -> requestPermission(result)
            "openNotificationSettings" -> {
                BatteryNotificationScheduler.openNotificationSettings(context)
                result.success(null)
            }
            "setHasEnabledAccounts" -> {
                val value = call.argument<Boolean>("value") ?: false
                BatteryNotificationScheduler.setHasEnabledAccounts(context, value)
                result.success(null)
            }
            "cancelNotifications" -> {
                BatteryNotificationScheduler.cancelNotifications(context)
                result.success(null)
            }
            "showSummaryNotification" -> {
                val count = (call.argument<Number>("count"))?.toInt() ?: 1
                result.success(
                    BatteryNotificationScheduler.showSummaryNotification(
                        context,
                        count.coerceAtLeast(1),
                    ),
                )
            }
            "isCancelled" -> result.success(isCancelledProvider())
            "consumePendingInboxOpen" -> result.success(
                BatteryNotificationScheduler.consumePendingInboxOpen(context),
            )
            "acquireForegroundLease" -> {
                BatteryNotificationScheduler.acquireForegroundLease { granted, code ->
                    if (detached) {
                        // Late grant after the engine/UI is gone: balance the
                        // native count immediately and never reply.
                        if (granted) BatteryNotificationScheduler.releaseForegroundLease()
                    } else if (!granted) {
                        result.error(
                            code ?: "background_busy",
                            "Background check is still stopping.",
                            null,
                        )
                    } else {
                        heldForegroundLeases++
                        result.success(true)
                    }
                }
            }
            "waitForBackgroundIdle" -> {
                BatteryNotificationScheduler.waitForBackgroundIdle(result)
            }
            "releaseForegroundLease" -> {
                // Only release a lease this bridge actually owns. Never touch
                // another owner's (GoogleBridge/resolver) count.
                if (heldForegroundLeases > 0) {
                    heldForegroundLeases--
                    BatteryNotificationScheduler.releaseForegroundLease()
                }
                result.success(null)
            }
            "backgroundFinished" -> {
                val finished = onBackgroundFinished
                if (finished == null) return false
                result.success(null)
                finished()
            }
            else -> return false
        }
        return true
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val pending = pendingPermissionResult
        pendingPermissionResult = null
        BatteryNotificationScheduler.ensureScheduled(context)
        pending?.success(BatteryNotificationScheduler.settings(context))
        return true
    }

    private fun releaseHeldForegroundLeases() {
        while (heldForegroundLeases > 0) {
            heldForegroundLeases--
            BatteryNotificationScheduler.releaseForegroundLease()
        }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33) {
            result.success(BatteryNotificationScheduler.settings(context))
            return
        }
        if (ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            BatteryNotificationScheduler.ensureScheduled(context)
            result.success(BatteryNotificationScheduler.settings(context))
            return
        }
        val host = activity
        if (host == null) {
            result.error(
                "ui_required",
                "Notification permission can only be requested from the app.",
                null,
            )
            return
        }
        if (pendingPermissionResult != null) {
            result.error(
                "permission_in_progress",
                "A notification permission request is already running.",
                null,
            )
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            host,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            PERMISSION_REQUEST_CODE,
        )
    }
}
