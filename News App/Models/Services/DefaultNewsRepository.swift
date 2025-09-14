//
//  DefaultNewsRepository.swift
//  News App
//

import Foundation

final class DefaultNewsRepository: NewsRepository {
    private let api: APIService
    private let store: DataStoreManager

    init(api: APIService = .shared, store: DataStoreManager = .shared) {
        self.api = api
        self.store = store
    }

    func fetchTopHeadlines() async throws -> [Article] {
        try await withCheckedThrowingContinuation { continuation in
            api.request(
                endpoint: AppConstants.baseURL,
                queryItems: [
                    URLQueryItem(name: "country", value: "us"),
                    URLQueryItem(name: "category", value: "business")
                ],
                responseType: NewsResponse.self
            ) { [store] result in
                switch result {
                case .success(let response):
                    store.replaceCachedArticles(with: response.articles)
                    continuation.resume(returning: response.articles)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func cachedHeadlines() -> [Article] {
        store.fetchCachedArticles()
    }

    func bookmarks() -> [Article] {
        store.fetchBookmarkedArticles()
    }

    func toggleBookmark(_ article: Article) {
        if isBookmarked(article) {
            store.removeBookmark(for: article)
        } else {
            store.saveBookmark(for: article)
        }
    }

    func isBookmarked(_ article: Article) -> Bool {
        // simple check based on url or title
        bookmarks().contains { $0.url == article.url || $0.title == article.title }
    }
}

