import UIKit

/// Creates the UIKit hierarchy without a storyboard and receives deep links.
final class ProgrammaticSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private weak var newsController: NewsListViewController?

    /// Builds window, navigation, ViewModel, and repository explicitly.
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let repository = AppEnvironment.makeRepository()
        let viewModel = NewsListViewModel(repository: repository)
        let newsController = NewsListViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: newsController)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        self.window = window
        self.newsController = newsController

        if let incomingURL = connectionOptions.urlContexts.first?.url {
            DispatchQueue.main.async { newsController.openDeepLink(incomingURL) }
        } else if let value = ProcessInfo.processInfo.environment["UITEST_DEEP_LINK"],
                  let testURL = URL(string: value) {
            DispatchQueue.main.async { newsController.openDeepLink(testURL) }
        }
    }

    /// Handles a deep link while the app is already running.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        _ = newsController?.openDeepLink(url)
    }

    /// Schedules a refresh after iOS moves the scene to the background.
    func sceneDidEnterBackground(_ scene: UIScene) {
        BackgroundRefreshManager.shared.schedule()
    }
}
