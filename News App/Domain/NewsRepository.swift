import Foundation

/// The ViewModel talks to this protocol instead of talking directly to the web
/// or Core Data. A protocol is like a promise: any repository must provide these
/// operations. Tests can therefore use a tiny fake repository with no network.
protocol NewsRepository {
    func fetchHeadlines(page: Int, pageSize: Int) async throws -> NewsPage
    func cachedHeadlines() async -> [Article]
    func bookmarks() async -> [Article]
    func setBookmarked(_ isBookmarked: Bool, article: Article) async

    /// Fetches a single fresh page of headlines for one followed topic/category.
    /// Has a default implementation below, so existing conformers (test fakes,
    /// `FixtureNewsRepository`) keep compiling unchanged; `DefaultNewsRepository`
    /// overrides it with a real, category-filtered network call.
    func fetchTopicHeadlines(_ topic: Topic) async throws -> [Article]
}

extension NewsRepository {
    /// Falls back to the general feed so a conformer that never heard of topics
    /// (any existing test fake) still behaves reasonably if this is ever called.
    func fetchTopicHeadlines(_ topic: Topic) async throws -> [Article] {
        let page = try await fetchHeadlines(page: 1, pageSize: 20)
        return page.articles
    }
}

