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
        return NewsPage(
            articles: response.articles,
            page: page,
            totalResults: response.totalResults
        )
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

