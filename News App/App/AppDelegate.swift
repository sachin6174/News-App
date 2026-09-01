import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    /// Registers system services before UIKit creates the first scene.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        BackgroundRefreshManager.shared.register()
        return true
    }

    /// Tells UIKit which programmatic scene delegate should create our window.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = ProgrammaticSceneDelegate.self
        return configuration
    }

    /// There is no per-scene data to clean up because shared state lives in Core Data.
    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {}
}

