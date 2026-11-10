package com.localmail.local_mail_client

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Gmail authorization and battery notification bridges live here for the UI
 * engine. Both are also registered on the headless engine in
 * [BackgroundMailJobService], so Gmail silent refresh works without an Activity.
 */
class MainActivity : FlutterActivity() {
    private var googleBridge: GoogleAuthBridge? = null
    private var batteryBridge: BatteryNotificationBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Mark foreground before the Flutter engine and repository.initialize()
        // run, and tear down any headless job that may already be refreshing a
        // token. This is intentionally earlier than configureFlutterEngine().
        BatteryNotificationScheduler.onActivityCreate(this)
        super.onCreate(savedInstanceState)
        if (intent?.getBooleanExtra(BatteryNotificationScheduler.EXTRA_OPEN_INBOX, false) == true) {
            BatteryNotificationScheduler.markPendingInboxOpen(this)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        googleBridge = GoogleAuthBridge(this, this, flutterEngine).also { it.attach() }
        batteryBridge = BatteryNotificationBridge(
            context = this,
            activity = this,
        ).also { it.attach(flutterEngine) }
    }

    override fun onStart() {
        super.onStart()
        BatteryNotificationScheduler.onActivityStart(this)
    }

    override fun onStop() {
        BatteryNotificationScheduler.onActivityStop(this)
        super.onStop()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(BatteryNotificationScheduler.EXTRA_OPEN_INBOX, false)) {
            BatteryNotificationScheduler.markPendingInboxOpen(this)
            batteryBridge?.notifyOpenInbox()
        }
    }

    @Deprecated("FlutterActivity still dispatches activity results here.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val handled = googleBridge?.onActivityResult(requestCode, resultCode, data) == true
        if (!handled) super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        val handled = batteryBridge?.onRequestPermissionsResult(
            requestCode,
            grantResults,
        ) == true
        if (!handled) super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        googleBridge?.detach()
        googleBridge = null
        batteryBridge?.detach()
        batteryBridge = null
        super.onDestroy()
    }
}
