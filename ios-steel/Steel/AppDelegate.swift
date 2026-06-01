import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        KeychainHelper.bootstrap()
        DataManager.shared.bootstrap()
        FontManager.shared.registerSavedFont()
        FontManager.shared.applyGlobalFont()
        NotificationManager.shared.requestAuthorization()
        NotificationManager.shared.rescheduleAll()
        NotificationManager.shared.scheduleStreakWarningIfNeeded()
        NotificationManager.shared.scheduleBirthdayNotifications(
            birthdayString: DataManager.shared.settings.birthdayDateString
        )
        NotificationManager.shared.checkBirthdayAndCongratulate()
        observeSignificantTimeChange()
        return true
    }

    private func observeSignificantTimeChange() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                DataManager.shared.rolloverIfNewDay()
            }
        }
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
