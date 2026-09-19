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

    /// The inverse of `articleURL(from:)`: builds the app's own deep link for a
    /// known HTTPS article URL, so a local notification or a widget tap can
    /// reuse this exact, already-tested routing path instead of a second one.
    static func appLink(forArticleURL articleURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "newsapp"
        components.host = "article"
        components.queryItems = [URLQueryItem(name: "url", value: articleURL.absoluteString)]
        return components.url
    }
}
