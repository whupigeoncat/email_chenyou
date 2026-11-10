package com.localmail.local_mail_client

import android.app.job.JobParameters
import android.app.job.JobService
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * One-shot headless FlutterEngine per periodic check. No foreground service,
 * no long-lived IMAP connection, and a hard watchdog so a stuck socket cannot
 * keep the process or job alive.
 */
class BackgroundMailJobService : JobService() {
    companion object {
        private const val WATCHDOG_MS = 75_000L
        private const val CANCEL_GRACE_MS = 4_000L
        private const val DART_ENTRYPOINT = "backgroundMailMain"

        @Volatile
        private var active: BackgroundMailJobService? = null

        fun hasActive(): Boolean = active != null
        fun activeService(): BackgroundMailJobService? = active
        fun activate(service: BackgroundMailJobService) {
            active = service
        }

        fun deactivate(service: BackgroundMailJobService) {
            if (active === service) active = null
        }

        fun cancelActive() {
            active?.requestCancelAndDestroy()
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var bridge: BatteryNotificationBridge? = null
    private var googleBridge: GoogleAuthBridge? = null
    private var parameters: JobParameters? = null
    private var finished = false

    @Volatile
    private var cancelled = false

    private val watchdog = Runnable { finishJob() }

    override fun onStartJob(params: JobParameters): Boolean {
        // Disabled setting, zero enabled accounts, or revoked permission must
        // remove the periodic wake instead of waking forever to do nothing.
        if (BatteryNotificationScheduler.getIntervalMinutes(this) <= 0 ||
            !BatteryNotificationScheduler.hasEnabledAccounts(this) ||
            !BatteryNotificationScheduler.notificationsUsable(this)
        ) {
            BatteryNotificationScheduler.cancelJob(this)
            jobFinished(params, false)
            return false
        }
        if (!BatteryNotificationScheduler.canRunBackground(this) ||
            !BatteryNotificationScheduler.beginBackground(this)
        ) {
            jobFinished(params, false)
            return false
        }
        parameters = params
        finished = false
        cancelled = false

        try {
            // FlutterEngine's default constructor registers generated plugins,
            // including secure storage and path_provider used by the headless
            // checker. Do not register GeneratedPluginRegistrant twice.
            val flutterEngine = FlutterEngine(applicationContext)
            engine = flutterEngine
            googleBridge = GoogleAuthBridge(this, null, flutterEngine).also { it.attach() }
            bridge = BatteryNotificationBridge(
                context = this,
                activity = null,
                isCancelledProvider = { cancelled },
                onBackgroundFinished = { finishJob() },
            )

            channel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                BatteryNotificationBridge.CHANNEL_NAME,
            ).also { methodChannel ->
                methodChannel.setMethodCallHandler { call, result ->
                    val notificationBridge = bridge
                    if (notificationBridge == null || !notificationBridge.handle(call, result)) {
                        result.notImplemented()
                    }
                }
            }

            val entrypoint = DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                DART_ENTRYPOINT,
            )
            flutterEngine.dartExecutor.executeDartEntrypoint(entrypoint)
        } catch (_: Throwable) {
            // Release the gate only after the partially created engine is gone.
            finishJob()
            return false
        }

        handler.postDelayed(watchdog, WATCHDOG_MS)
        return true
    }

    /** Bounded cancellation for a foreground lease or settings change. */
    fun requestCancelAndDestroy() {
        cancelled = true
        try {
            channel?.invokeMethod("cancel", null)
        } catch (_: Throwable) {
            // Engine may already be gone.
        }
        handler.postDelayed({ finishJob() }, CANCEL_GRACE_MS)
    }

    override fun onStopJob(params: JobParameters): Boolean {
        cancelled = true
        finishJob()
        return false
    }

    override fun onDestroy() {
        finishJob()
        super.onDestroy()
    }

    private fun finishJob() {
        if (finished) return
        finished = true
        cancelled = true
        handler.removeCallbacks(watchdog)
        try {
            // Tear down the Dart isolate and channel handlers BEFORE releasing
            // the process gate. Foreground resolvers must not start while a
            // cancelled engine can still be finishing a token refresh.
            runCatching { channel?.setMethodCallHandler(null) }
            channel = null
            runCatching { bridge?.detach() }
            bridge = null
            runCatching { googleBridge?.detach() }
            googleBridge = null
            runCatching { engine?.destroy() }
            engine = null
        } finally {
            // Even if one cleanup step throws, the gate must be released and
            // JobScheduler must get a terminal callback.
            runCatching { BatteryNotificationScheduler.endBackground(this) }
            val params = parameters
            parameters = null
            if (params != null) {
                runCatching { jobFinished(params, false) }
            }
            runCatching { stopSelf() }
        }
    }
}
