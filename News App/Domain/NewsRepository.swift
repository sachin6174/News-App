import Foundation

/// The ViewModel talks to this protocol instead of talking directly to the web
/// or Core Data. A protocol is like a promise: any repository must provide these
/// operations. Tests can therefore use a tiny fake repository with no network.
protocol NewsRepository {
    func fetchHeadlines(page: Int, pageSize: Int) async throws -> NewsPage
    func cachedHeadlines() async -> [Article]
    func bookmarks() async -> [Article]
    func setBookmarked(_ isBookmarked: Bool, article: Article) async
}

