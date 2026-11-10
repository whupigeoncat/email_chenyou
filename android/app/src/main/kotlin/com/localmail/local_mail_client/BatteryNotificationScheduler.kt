package com.localmail.local_mail_client

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

/**
 * Persisted, battery-friendly INBOX check scheduler and notification poster.
 *
 * A single periodic JobScheduler job is kept. Re-scheduling with the same id
 * would stop a running job, so `ensureScheduled` is idempotent and only
 * rebuilds when the interval actually changed or the job is missing.
 */
object BatteryNotificationScheduler {
    const val JOB_ID = 4819
    const val CHANNEL_ID = "new_mail"
    const val NOTIFICATION_ID = 4820

    const val EXTRA_OPEN_INBOX = "com.localmail.local_mail_client.OPEN_INBOX"

    private const val PREFS = "battery_notification_settings"
    private const val KEY_INTERVAL = "interval_minutes"
    private const val KEY_LAST_SCHEDULED = "last_scheduled_minutes"
    private const val KEY_HAS_ACCOUNTS = "has_enabled_accounts"
    private const val KEY_PENDING_OPEN = "pending_open_inbox"

    private const val DEFAULT_INTERVAL = 30
    private const val GRACE_AFTER_STOP_MS = 35_000L
    private const val FOREGROUND_WAIT_MS = 6_000L

    private val mainHandler = Handler(Looper.getMainLooper())
    private val leaseLock = Any()
    private val leaseWaiters = mutableListOf<MethodChannel.Result>()
    private val leaseCallbacks = mutableListOf<(Boolean, String?) -> Unit>()
    private val idleWaiters = mutableListOf<MethodChannel.Result>()
    private var foregroundLeaseCount = 0

    @Volatile
    private var foreground = false

    private var stopRunnable: Runnable? = null

    fun onActivityCreate(context: Context) {
        synchronized(leaseLock) {
            foreground = true
        }
        stopRunnable?.let { mainHandler.removeCallbacks(it) }
        cancelNotifications(context)
        // A job that started before the UI did must not keep a second engine or
        // refresh a token concurrently with repository.initialize().
        BackgroundMailJobService.cancelActive()
        ensureScheduled(context)
    }

    fun onActivityStart(context: Context) {
        synchronized(leaseLock) {
            foreground = true
        }
        stopRunnable?.let { mainHandler.removeCallbacks(it) }
        stopRunnable = null
        cancelNotifications(context)
        // Warm resume can find a headless job that started while the app was
        // backgrounded. Cancel it early as well as on cold create.
        BackgroundMailJobService.cancelActive()
        ensureScheduled(context)
    }

    fun onActivityStop(context: Context) {
        // AppLifecycleManager keeps IDLE sockets for a 30s grace period. Keep
        // the background check out of that window as well.
        stopRunnable?.let { mainHandler.removeCallbacks(it) }
        val runnable = Runnable {
            synchronized(leaseLock) {
                foreground = false
            }
        }
        stopRunnable = runnable
        mainHandler.postDelayed(runnable, GRACE_AFTER_STOP_MS)
    }

    fun isForeground(): Boolean = foreground

    fun getIntervalMinutes(context: Context): Int {
        return prefs(context).getInt(KEY_INTERVAL, DEFAULT_INTERVAL)
    }

    fun setHasEnabledAccounts(context: Context, value: Boolean) {
        prefs(context).edit().putBoolean(KEY_HAS_ACCOUNTS, value).apply()
        if (!value) {
            cancelJob(context)
            cancelNotifications(context)
        } else {
            ensureScheduled(context)
        }
    }

    fun setIntervalMinutes(context: Context, minutes: Int): Map<String, Any?> {
        val normalized = when (minutes) {
            0, 15, 30, 60 -> minutes
            else -> DEFAULT_INTERVAL
        }
        prefs(context).edit().putInt(KEY_INTERVAL, normalized).apply()
        if (normalized == 0) {
            cancelJob(context)
            cancelNotifications(context)
        } else {
            ensureScheduled(context)
        }
        return settings(context)
    }

    fun settings(context: Context): Map<String, Any?> {
        val permission = permissionGranted(context)
        val appEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        val channel = if (Build.VERSION.SDK_INT >= 26) {
            notificationManager(context).getNotificationChannel(CHANNEL_ID)
        } else {
            null
        }
        val channelEnabled = channel == null ||
            channel.importance != NotificationManager.IMPORTANCE_NONE
        return mapOf(
            "intervalMinutes" to getIntervalMinutes(context),
            "permissionGranted" to permission,
            "appNotificationsEnabled" to appEnabled,
            "channelEnabled" to channelEnabled,
            "canRequestPermission" to (Build.VERSION.SDK_INT >= 33 && !permission),
        )
    }

    fun notificationsUsable(context: Context): Boolean {
        val map = settings(context)
        return map["permissionGranted"] == true &&
            map["appNotificationsEnabled"] == true &&
            map["channelEnabled"] == true
    }

    fun canRunBackground(context: Context): Boolean {
        return !foreground &&
            getIntervalMinutes(context) > 0 &&
            hasEnabledAccounts(context) &&
            notificationsUsable(context)
    }

    fun hasEnabledAccounts(context: Context): Boolean {
        return prefs(context).getBoolean(KEY_HAS_ACCOUNTS, false)
    }

    /** Idempotent. Never calls schedule() for an unchanged live job. */
    fun ensureScheduled(context: Context) {
        val interval = getIntervalMinutes(context)
        val hasAccounts = prefs(context).getBoolean(KEY_HAS_ACCOUNTS, false)
        if (interval <= 0 || !hasAccounts || !notificationsUsable(context)) {
            cancelJob(context)
            return
        }
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
        val lastScheduled = prefs(context).getInt(KEY_LAST_SCHEDULED, -1)
        val pending = if (Build.VERSION.SDK_INT >= 24) {
            scheduler.getPendingJob(JOB_ID)
        } else {
            null
        }
        if (Build.VERSION.SDK_INT >= 24) {
            if (pending != null && lastScheduled == interval) return
            if (pending != null) scheduler.cancel(JOB_ID)
        } else if (lastScheduled == interval) {
            // Cannot query pending jobs before API 24; trust persisted state.
            return
        }

        val builder = JobInfo.Builder(
            JOB_ID,
            ComponentName(context, BackgroundMailJobService::class.java),
        )
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setPersisted(true)
        if (Build.VERSION.SDK_INT >= 26) {
            builder.setRequiresBatteryNotLow(true)
        }
        if (Build.VERSION.SDK_INT >= 24) {
            builder.setPeriodic(interval * 60_000L, 5 * 60_000L)
        } else {
            @Suppress("DEPRECATION")
            builder.setPeriodic(interval * 60_000L)
        }
        scheduler.schedule(builder.build())
        prefs(context).edit().putInt(KEY_LAST_SCHEDULED, interval).apply()
    }

    fun cancelJob(context: Context) {
        context.getSystemService(JobScheduler::class.java)?.cancel(JOB_ID)
        prefs(context).edit().putInt(KEY_LAST_SCHEDULED, -1).apply()
    }

    fun cancelActiveJob() {
        BackgroundMailJobService.cancelActive()
    }

    fun beginBackground(service: BackgroundMailJobService): Boolean {
        synchronized(leaseLock) {
            if (foreground || foregroundLeaseCount > 0) return false
            if (BackgroundMailJobService.hasActive()) return false
            BackgroundMailJobService.activate(service)
            return true
        }
    }

    fun endBackground(service: BackgroundMailJobService) {
        synchronized(leaseLock) {
            BackgroundMailJobService.deactivate(service)
            completeLeaseWaitersLocked()
            completeLeaseCallbacksLocked()
            completeIdleWaitersLocked()
        }
    }

    /**
     * Blocks Dart main/runApp until a pre-existing headless job has actually
     * torn down its engine. Avoids opening the DB while the job still writes.
     */
    fun waitForBackgroundIdle(result: MethodChannel.Result) {
        val service: BackgroundMailJobService?
        synchronized(leaseLock) {
            service = BackgroundMailJobService.activeService()
            if (service == null) {
                result.success(true)
                return
            }
            idleWaiters.add(result)
        }
        service?.requestCancelAndDestroy()
        mainHandler.postDelayed({
            synchronized(leaseLock) {
                completeIdleWaitersLocked(force = true)
            }
        }, FOREGROUND_WAIT_MS)
    }

    fun acquireForegroundLease(result: MethodChannel.Result) {
        val service: BackgroundMailJobService?
        synchronized(leaseLock) {
            foregroundLeaseCount++
            service = BackgroundMailJobService.activeService()
            if (service == null) {
                result.success(true)
                return
            }
            leaseWaiters.add(result)
        }
        // This call already owns the foreground lease; cancel and bound the
        // wait. If the engine is still alive after the bound, the service tears
        // it down so repository.initialize() cannot share a token refresh.
        service?.requestCancelAndDestroy()
        mainHandler.postDelayed({
            synchronized(leaseLock) {
                completeLeaseWaitersLocked(force = true)
            }
        }, FOREGROUND_WAIT_MS)
    }

    /**
     * Callback lease used by the visible Google authorization bridge. The
     * callback runs on the main thread. A false result is fail-closed: callers
     * must not start a token refresh or interactive authorization.
     */
    fun acquireForegroundLease(callback: (Boolean, String?) -> Unit) {
        val service: BackgroundMailJobService?
        synchronized(leaseLock) {
            foregroundLeaseCount++
            service = BackgroundMailJobService.activeService()
            if (service == null) {
                callback(true, null)
                return
            }
            leaseCallbacks.add(callback)
        }
        service?.requestCancelAndDestroy()
        mainHandler.postDelayed({
            synchronized(leaseLock) {
                completeLeaseCallbacksLocked(force = true)
            }
        }, FOREGROUND_WAIT_MS)
    }

    fun releaseForegroundLease() {
        synchronized(leaseLock) {
            if (foregroundLeaseCount > 0) foregroundLeaseCount--
        }
    }

    fun completeForegroundWaiters() {
        synchronized(leaseLock) {
            completeLeaseWaitersLocked()
            completeLeaseCallbacksLocked()
            completeIdleWaitersLocked()
        }
    }

    fun markPendingInboxOpen(context: Context) {
        prefs(context).edit().putBoolean(KEY_PENDING_OPEN, true).apply()
    }

    fun consumePendingInboxOpen(context: Context): Boolean {
        val pending = prefs(context).getBoolean(KEY_PENDING_OPEN, false)
        if (pending) prefs(context).edit().putBoolean(KEY_PENDING_OPEN, false).apply()
        return pending
    }

    fun openNotificationSettings(context: Context) {
        val intent = if (Build.VERSION.SDK_INT >= 26) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        } else {
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                android.net.Uri.parse("package:${context.packageName}"),
            )
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun showSummaryNotification(context: Context, count: Int): Boolean {
        // A late Dart call must not post after the user disabled the setting,
        // removed all accounts, or returned to the UI and cancelled the job.
        if (!canRunBackground(context) || !BackgroundMailJobService.hasActive()) {
            return false
        }
        if (!notificationsUsable(context)) return false
        ensureChannel(context)
        val openIntent = Intent(context, MainActivity::class.java)
            .putExtra(EXTRA_OPEN_INBOX, true)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        val contentIntent = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            openIntent,
            pendingFlags,
        )
        val text = if (count <= 1) "有新邮件" else "$count 封新邮件"
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_mail)
            .setContentTitle("本地邮箱")
            .setContentText(text)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setNumber(count)
            .setCategory(Notification.CATEGORY_EMAIL)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setContentIntent(contentIntent)
            .build()
        return try {
            notificationManager(context).notify(NOTIFICATION_ID, notification)
            true
        } catch (_: SecurityException) {
            false
        }
    }

    fun cancelNotifications(context: Context) {
        notificationManager(context).cancel(NOTIFICATION_ID)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = notificationManager(context)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "新邮件",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "后台定时检查新邮件"
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    private fun notificationManager(context: Context): NotificationManager {
        return context.getSystemService(NotificationManager::class.java)
    }

    private fun permissionGranted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 33) return true
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun completeLeaseWaitersLocked(force: Boolean = false) {
        if (leaseWaiters.isEmpty()) return
        if (!force && BackgroundMailJobService.hasActive()) return
        val waiters = leaseWaiters.toList()
        leaseWaiters.clear()
        for (waiter in waiters) {
            if (BackgroundMailJobService.hasActive()) {
                // Never-granted lease: undo the optimistic count so a timeout
                // cannot permanently block future background jobs.
                if (foregroundLeaseCount > 0) foregroundLeaseCount--
                waiter.error(
                    "background_busy",
                    "Background check did not stop in time.",
                    null,
                )
            } else {
                waiter.success(true)
            }
        }
    }

    private fun completeLeaseCallbacksLocked(force: Boolean = false) {
        if (leaseCallbacks.isEmpty()) return
        if (!force && BackgroundMailJobService.hasActive()) return
        val callbacks = leaseCallbacks.toList()
        leaseCallbacks.clear()
        val busy = BackgroundMailJobService.hasActive()
        for (callback in callbacks) {
            if (busy) {
                if (foregroundLeaseCount > 0) foregroundLeaseCount--
                callback(false, "background_busy")
            } else {
                callback(true, null)
            }
        }
    }

    private fun completeIdleWaitersLocked(force: Boolean = false) {
        if (idleWaiters.isEmpty()) return
        if (!force && BackgroundMailJobService.hasActive()) return
        val waiters = idleWaiters.toList()
        idleWaiters.clear()
        for (waiter in waiters) {
            if (BackgroundMailJobService.hasActive()) {
                waiter.error(
                    "background_busy",
                    "Background check did not stop in time.",
                    null,
                )
            } else {
                waiter.success(true)
            }
        }
    }
}
