//
//  NewsViewModel.swift
//  News App
//
//  Super simple MVVM for the news list.
//

import Foundation

final class NewsViewModel {
    enum Mode {
        case all
        case bookmarks
    }

    // MARK: - State
    private(set) var allArticles: [Article] = []
    private(set) var bookmarkedArticles: [Article] = []
    var mode: Mode = .all
    var filterText: String = "" { didSet { onChange?() } }

    // MARK: - Outputs
    var onChange: (() -> Void)?

    private let store = DataStoreManager.shared

    // MARK: - Derived
    var displayedArticles: [Article] {
        let base: [Article] = mode == .all ? allArticles : bookmarkedArticles
        let text = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(text) }
    }

    // MARK: - Actions
    func loadBookmarks() {
        bookmarkedArticles = store.fetchBookmarkedArticles()
        onChange?()
    }

    func fetchNews(completion: ((Error?) -> Void)? = nil) {
        APIService.shared.request(
            endpoint: AppConstants.baseURL,
            queryItems: [
                URLQueryItem(name: "country", value: "us"),
                URLQueryItem(name: "category", value: "business")
            ],
            responseType: NewsResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.allArticles = response.articles
                    DataStoreManager.shared.replaceCachedArticles(with: response.articles)
                    self?.onChange?()
                    completion?(nil)
                case .failure(let error):
                    // Offline fallback
                    let cached = DataStoreManager.shared.fetchCachedArticles()
                    self?.allArticles = cached
                    self?.onChange?()
                    completion?(error)
                }
            }
        }
    }

    func refresh(completion: ((Error?) -> Void)? = nil) {
        fetchNews(completion: completion)
    }

    func toggleBookmark(for article: Article) {
        if isBookmarked(article) {
            store.removeBookmark(for: article)
            bookmarkedArticles.removeAll { $0.url == article.url || $0.title == article.title }
        } else {
            store.saveBookmark(for: article)
            bookmarkedArticles.append(article)
        }
        onChange?()
    }

    func isBookmarked(_ article: Article) -> Bool {
        return bookmarkedArticles.contains { $0.url == article.url || $0.title == article.title }
    }
}

