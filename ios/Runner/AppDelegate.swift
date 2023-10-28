import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // same duration as on android
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(120))

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
