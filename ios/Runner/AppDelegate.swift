import Flutter
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configurar Firebase
    FirebaseApp.configure()
   
    // Registrar plugins de Flutter

    GeneratedPluginRegistrant.register(with: self)
   
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
