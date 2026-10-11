import UIKit
import Flutter
import workmanager_apple

@main // This replaces @UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "WatchSyncBridge") {
      WatchSyncBridge.register(with: registrar)
    }

    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
        // Der Hintergrund-Task laeuft in einer EIGENEN FlutterEngine. Ohne diese Zeile
        // existiert der Watch-Kanal dort nicht und der Sync aus dem Hintergrund schlaegt fehl.
        if let registrar = registry.registrar(forPlugin: "WatchSyncBridge") {
          WatchSyncBridge.register(with: registrar)
        }
    }

    // Hintergrundaktualisierung: workmanager_apple nutzt BGTaskScheduler (BGAppRefreshTask),
    // nicht die seit iOS 13 abgeloeste Fetch-API. Der Handler MUSS vor dem Ende von
    // didFinishLaunching registriert werden, sonst wirft iOS beim Start eine Exception.
    // Die Kennung muss zusaetzlich unter BGTaskSchedulerPermittedIdentifiers in der
    // Info.plist stehen - fehlt sie, schlaegt die Registrierung lautlos fehl.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "fetch_task",
      frequency: NSNumber(value: 4 * 60 * 60)   // fruehestens alle 4 Stunden; iOS entscheidet selbst
    )

    // For flutter_local_notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
