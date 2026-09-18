import Foundation

/// `AppConfiguration` is the one small place where the app reads its settings.
///
/// Think of this type like a labelled settings box. Other objects may ask the box
/// for the headline-service address, but they never need to know how that service
/// talks to a news provider. Keeping that knowledge outside the app prevents a
/// provider credential from being shipped inside an iOS binary.
struct AppConfiguration: Sendable {
    let newsBaseURL: URL

    /// Builds the normal configuration used by the installed application. The
    /// server owns any third-party provider credential; the app only calls this
    /// public, purpose-built endpoint.
    static func live() -> AppConfiguration {
        AppConfiguration(
            newsBaseURL: URL(string: "https://newsly-live-headlines.sachin332883.chatgpt.site/api/top-headlines")!
        )
    }

    /// A safe configuration for UI tests. It never contacts the real internet.
    static let uiTesting = AppConfiguration(
        newsBaseURL: URL(string: "https://example.invalid/news")!
    )
}
