import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate, MessagingDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 1. Firebase - PRIMERO
        FirebaseApp.configure()
        print("🔥 Firebase configurado")

        // 2. Configurar Messaging DELEGATE
        Messaging.messaging().delegate = self
        print("📱 Messaging delegate configurado")

        // 3. Configurar notificaciones push
        configureNotifications(application: application)

        // 4. Plugins de Flutter - DESPUÉS de Firebase
        GeneratedPluginRegistrant.register(with: self)
        print("🔌 Plugins de Flutter registrados")

        // 5. Llamar al método padre
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func configureNotifications(application: UIApplication) {
        print("🔔 Configurando notificaciones...")

        // Para iOS 10+
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self

            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { granted, error in
                    if let error = error {
                        print("❌ Error al solicitar permisos: \(error.localizedDescription)")
                    }
                    print("✅ Permiso para notificaciones: \(granted ? "OTORGADO" : "DENEGADO")")

                    if granted {
                        DispatchQueue.main.async {
                            application.registerForRemoteNotifications()
                        }
                    }
                }
            )
        } else {
            // Para iOS 9
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        }
    }

    // MARK: - APNs Token Registration

    override func application(_ application: UIApplication,
                             didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("✅ APNs token registrado exitosamente")

        // Convertir token a string legible
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 APNs Token: \(tokenString)")

        // Pasar el token APNs a Firebase Messaging (CRÍTICO)
        Messaging.messaging().apnsToken = deviceToken

        // Llamar al método padre para que Flutter también lo reciba
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    override func application(_ application: UIApplication,
                             didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Error al registrar APNs: \(error.localizedDescription)")
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    // MARK: - Firebase Messaging Delegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 Firebase Messaging Token recibido: \(fcmToken ?? "nil")")

        // Guardar token localmente
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "fcm_token")
            print("💾 Token FCM guardado: \(token.prefix(20))...")
        }

        // Enviar notificación a Flutter (si necesitas acceder al token en Dart)
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
    }

    // MARK: - Manejo de notificaciones en foreground (opcional)

    @available(iOS 10.0, *)
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                        willPresent notification: UNNotification,
                                        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo

        print("📲 Notificación recibida en foreground: \(userInfo)")

        // Permitir que se muestre la notificación incluso cuando la app está activa
        completionHandler([[.banner, .sound, .badge]])
    }
}