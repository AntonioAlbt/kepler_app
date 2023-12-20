import UIKit
import Flutter
import workmanager

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    WorkmanagerPlugin.setPluginRegistrantCallback { registry in  
      // The following code will be called upon WorkmanagerPlugin's registration.
      // Note : all of the app's plugins may not be required in this context ;
      // instead of using GeneratedPluginRegistrant.register(with: registry),
      // you may want to register only specific plugins.
      GeneratedPluginRegistrant.register(with: registry)
    }

    // same duration as on android, in seconds
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(300*60))

    // for flutter_local_notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
