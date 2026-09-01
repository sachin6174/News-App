import Foundation

/// The outer JSON object returned by NewsAPI.
struct NewsResponse: Decodable, Sendable {
    let status: String
    let totalResults: Int
    let articles: [Article]
}

/// One story shown in the list and detail screen.
///
/// `Codable` describes how Swift values map to JSON. `Hashable` lets us remove
/// duplicate stories when two API pages overlap. `Identifiable` gives SwiftUI a
/// stable name for the story without adding a made-up database identifier.
struct Article: Codable, Hashable, Identifiable, Sendable {
    let source: Source?
    let author: String?
    let title: String
    let description: String?
    let url: String
    let urlToImage: String?
    let publishedAt: String
    let content: String?

    /// The publisher URL is normally unique and stays stable between launches.
    /// A title/date fallback also keeps old cache rows usable after migration.
    var id: String {
        url.isEmpty ? "\(title)|\(publishedAt)" : url
    }
}

/// The publisher information nested inside an article's JSON.
struct Source: Codable, Hashable, Sendable {
    let id: String?
    let name: String
}

/// A small value returned by the repository for a single page of results.
struct NewsPage: Equatable, Sendable {
    let articles: [Article]
    let page: Int
    let totalResults: Int
}

