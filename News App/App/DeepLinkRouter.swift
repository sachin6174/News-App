import Foundation

/// Parses URLs without knowing anything about UIKit, so rules are easy to test.
enum DeepLinkRouter {
    /// Accepts `newsapp://article?url=https%3A%2F%2Fexample.com`.
    /// Only HTTPS destinations are allowed; unsafe schemes are rejected.
    static func articleURL(from deepLink: URL) -> URL? {
        guard deepLink.scheme?.lowercased() == "newsapp",
              deepLink.host?.lowercased() == "article",
              let components = URLComponents(url: deepLink, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let articleURL = URL(string: value),
              articleURL.scheme?.lowercased() == "https" else {
            return nil
        }
        return articleURL
    }
}
