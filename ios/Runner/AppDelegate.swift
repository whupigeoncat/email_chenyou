import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let backgroundChannelName = "com.localmail.client/background_task"
  private var backgroundChannel: FlutterMethodChannel?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: AppDelegate.backgroundChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    backgroundChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate released", details: nil))
        return
      }
      switch call.method {
      case "beginBackgroundTask":
        self.beginBackgroundTask()
        result(nil)
      case "endBackgroundTask":
        self.endBackgroundTask()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func beginBackgroundTask() {
    if backgroundTask != .invalid {
      return
    }
    var taskId: UIBackgroundTaskIdentifier = .invalid
    taskId = UIApplication.shared.beginBackgroundTask(
      withName: "LocalMailBackgroundGrace"
    ) { [weak self] in
      guard let self else { return }
      // Clear the active id first so a repeated expiry cannot double-end it.
      let expired = self.backgroundTask
      self.backgroundTask = .invalid
      self.backgroundChannel?.invokeMethod("onBackgroundTaskExpiring", arguments: nil)
      if expired != .invalid {
        UIApplication.shared.endBackgroundTask(expired)
      }
    }
    backgroundTask = taskId
  }

  private func endBackgroundTask() {
    let task = backgroundTask
    backgroundTask = .invalid
    if task != .invalid {
      UIApplication.shared.endBackgroundTask(task)
    }
  }
}
