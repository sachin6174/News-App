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
    var allArticles: [Article] = []
    var bookmarkedArticles: [Article] = []
    var mode: Mode = .all
    var filterText: String = "" { didSet { onChange?() } }

    // MARK: - Outputs
    var onChange: (() -> Void)?

    private let repo: NewsRepository
    
    init(repo: NewsRepository = DefaultNewsRepository()) {
        self.repo = repo
    }

    // MARK: - Derived
    var displayedArticles: [Article] {
        let base: [Article] = mode == .all ? allArticles : bookmarkedArticles
        let text = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(text) }
    }

    // MARK: - Actions
    func loadBookmarks() {
        bookmarkedArticles = repo.bookmarks()
        onChange?()
    }

    func fetchNews(completion: ((Error?) -> Void)? = nil) {
        Task { @MainActor in
            do {
                let articles = try await repo.fetchTopHeadlines()
                self.allArticles = articles
                self.onChange?()
                completion?(nil)
            } catch {
                self.allArticles = repo.cachedHeadlines()
                self.onChange?()
                completion?(error)
            }
        }
    }

    func refresh(completion: ((Error?) -> Void)? = nil) {
        fetchNews(completion: completion)
    }

    func toggleBookmark(for article: Article) {
        repo.toggleBookmark(article)
        loadBookmarks()
    }

    func isBookmarked(_ article: Article) -> Bool {
        return repo.isBookmarked(article)
    }
}
