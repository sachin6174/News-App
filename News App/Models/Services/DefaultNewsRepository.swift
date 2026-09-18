//
//  DefaultNewsRepository.swift
//  News App
//

import Foundation

final class DefaultNewsRepository: NewsRepository {
    private let api: NewsAPIService
    private let store: DataStoreManager

    init(api: NewsAPIService = NewsAPIService(), store: DataStoreManager = .shared) {
        self.api = api
        self.store = store
    }

    /// Gets a page from the server, then saves it before returning it to the UI.
    func fetchHeadlines(page: Int, pageSize: Int) async throws -> NewsPage {
        let response = try await api.fetchHeadlines(page: page, pageSize: pageSize)
        try await store.storeCached(response.articles, page: page)

        if page == 1 {
            // Both a foreground refresh and BackgroundRefreshManager land here,
            // so this is the one place that needs to notice a new top story and
            // keep the widget's shared snapshot current.
            BreakingNewsNotifier.evaluate(latestPageOneArticles: response.articles)
            WidgetDataWriter.write(topHeadlines: response.articles)
        }

        return NewsPage(
            articles: response.articles,
            page: page,
            totalResults: response.totalResults
        )
    }

    /// Fetches one topic's headlines fresh and updates its small offline cache.
    func fetchTopicHeadlines(_ topic: Topic) async throws -> [Article] {
        let response = try await api.fetchHeadlines(page: 1, pageSize: 20, category: topic)
        TopicArticleCache.shared.store(response.articles, for: topic)
        return response.articles
    }

    func cachedHeadlines() async -> [Article] {
        await store.fetchCachedArticles()
    }

    func bookmarks() async -> [Article] {
        await store.fetchBookmarkedArticles()
    }

    func setBookmarked(_ isBookmarked: Bool, article: Article) async {
        await store.setBookmarked(isBookmarked, article: article)
    }
}

