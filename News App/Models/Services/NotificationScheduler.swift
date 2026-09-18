import UserNotifications

/// Schedules and routes local (on-device) breaking-news alerts.
///
/// Nothing here talks to a push server: the app itself notices a new top story
/// (see `BreakingNewsNotifier` below) whenever it fetches page one, whether that
/// fetch happened in the foreground or inside `BackgroundRefreshManager`, and
/// asks iOS to show a local notification. Tapping that notification reuses the
/// exact same, already-tested `newsapp://article?url=` route a shared link uses.
///
/// `@unchecked Sendable` mirrors `DataStoreManager` elsewhere in this project: a
/// singleton whose delegate callbacks can arrive off the main thread, and whose
/// one mutable property (`onOpenArticle`) is set once during scene setup and
/// only ever invoked back on the main actor.
final class NotificationScheduler: NSObject, @unchecked Sendable {
    static let shared = NotificationScheduler()

    /// Set by the scene delegate once it has a live `NewsListViewController`, so
    /// a notification tap (including one that cold-launches the app) can open
    /// the matching article.
    var onOpenArticle: ((URL) -> Void)?

    private static let articleURLKey = "articleURL"
    private static let breakingNewsEnabledKey = "notifications.breakingNewsEnabled"

    private override init() {
        super.init()
    }

    /// Whether the reader turned on breaking-news alerts in the Topics screen.
    /// Defaults to `false`, so nothing changes for anyone who never opens that
    /// screen, and no permission prompt is ever triggered implicitly.
    static var isBreakingNewsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: breakingNewsEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: breakingNewsEnabledKey) }
    }

    /// Call once, early (app launch), so a tap that cold-launches the app is
    /// still delivered once this delegate is set — `UNUserNotificationCenter`
    /// buffers the response until a delegate exists.
    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Asks the user for permission. Call this only from an explicit action
    /// (the Topics screen's alert toggle), never automatically at launch, so
    /// the system prompt has context the user can reason about.
    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                DispatchQueue.main.async { completion(true) }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async { completion(granted) }
                }
            default:
                // Denied or restricted: only Settings can change this now.
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    /// Schedules one local alert for a new top story. Silently does nothing if
    /// the user never granted permission.
    func notifyNewTopStory(_ article: Article) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else { return }

            let content = UNMutableNotificationContent()
            content.title = L10n.text("notification.breaking.title")
            content.body = article.title
            content.sound = .default
            content.userInfo = [Self.articleURLKey: article.url]

            let request = UNNotificationRequest(
                identifier: "breaking-news-\(article.id)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            center.add(request)
        }
    }
}

extension NotificationScheduler: UNUserNotificationCenterDelegate {
    /// Lets the banner still appear while the app is already frontmost.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    /// Routes a tap through the same validated deep-link path a shared link uses.
    /// `UNUserNotificationCenterDelegate` callbacks are not guaranteed to land on
    /// the main thread, so the actual UIKit navigation is hopped onto the main
    /// actor before touching anything view-related.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let urlString = response.notification.request.content.userInfo[Self.articleURLKey] as? String,
           let articleURL = URL(string: urlString),
           let deepLink = DeepLinkRouter.appLink(forArticleURL: articleURL) {
            Task { @MainActor in
                NotificationScheduler.shared.onOpenArticle?(deepLink)
            }
        }
        completionHandler()
    }
}

/// Compares the newest top headline against the last one the reader was told
/// about, and asks `NotificationScheduler` to post an alert only when a
/// genuinely new story has appeared.
enum BreakingNewsNotifier {
    private static let lastNotifiedArticleIDKey = "breakingNews.lastNotifiedArticleID"

    static func evaluate(latestPageOneArticles: [Article]) {
        guard NotificationScheduler.isBreakingNewsEnabled,
              let topStory = latestPageOneArticles.first else { return }

        let defaults = UserDefaults.standard
        let previousID = defaults.string(forKey: lastNotifiedArticleIDKey)
        guard topStory.id != previousID else { return }
        defaults.set(topStory.id, forKey: lastNotifiedArticleIDKey)

        // Skip the very first comparison (no previous ID on record yet) so
        // turning this on, or installing the app, never fires a notification
        // for whatever headline simply happened to already be on top.
        guard previousID != nil else { return }

        NotificationScheduler.shared.notifyNewTopStory(topStory)
    }
}
