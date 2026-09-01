import Foundation

/// `AppConfiguration` is the one small place where the app reads its settings.
///
/// Think of this type like a labelled settings box. Other objects may ask the box
/// for the server address or API token, but they never need to know where those
/// values came from. Keeping that knowledge here makes the rest of the app easier
/// to test and, most importantly, keeps secret values out of Swift source files.
struct AppConfiguration: Sendable {
    let newsBaseURL: URL
    let apiToken: String

    /// Builds the normal configuration used by the installed application.
    ///
    /// During development and CI, `NEWS_API_KEY` can be supplied as an environment
    /// variable. In an Archive, Xcode can place the same value in Info.plist from a
    /// user-only build setting. We trim whitespace because copied keys sometimes
    /// contain an invisible newline at the end.
    static func live(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> AppConfiguration {
        let environmentToken = environment["NEWS_API_KEY"]
        let bundledToken = bundle.object(forInfoDictionaryKey: "NEWS_API_KEY") as? String
        let token = (environmentToken ?? bundledToken ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return AppConfiguration(
            newsBaseURL: URL(string: "https://newsapi.org/v2/top-headlines")!,
            apiToken: token
        )
    }

    /// A safe configuration for UI tests. It never contacts the real internet.
    static let uiTesting = AppConfiguration(
        newsBaseURL: URL(string: "https://example.invalid/news")!,
        apiToken: "ui-test-token"
    )
}
