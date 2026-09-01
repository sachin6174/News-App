import Foundation

/// `@MainActor` guarantees that every value observed by UIKit changes on the main
/// thread. UIKit is like a one-lane road: all visual changes must use that lane.
@MainActor
final class NewsListViewModel {
    enum Mode: Equatable {
        case all
        case bookmarks
    }

    enum State: Equatable {
        case idle
        case loading
        case content(isOffline: Bool)
        case empty
        case failed(message: String)
    }

    private(set) var allArticles: [Article] = []
    private(set) var bookmarkedArticles: [Article] = []
    private(set) var state: State = .idle
    private(set) var isLoadingNextPage = false

    var mode: Mode = .all {
        didSet { notifyChange() }
    }
    var filterText = "" {
        didSet { notifyChange() }
    }

    var onChange: (() -> Void)?
    var onAnnouncement: ((String) -> Void)?

    private let repository: NewsRepository
    private let pageSize: Int
    private var currentPage = 0
    private var totalResults = Int.max
    private var loadTask: Task<Void, Never>?

    init(repository: NewsRepository = DefaultNewsRepository(), pageSize: Int = 20) {
        self.repository = repository
        self.pageSize = pageSize
    }

    /// The exact list the table should show after segment and search filtering.
    var displayedArticles: [Article] {
        let base = mode == .all ? allArticles : bookmarkedArticles
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }

        return base.filter { article in
            article.title.localizedCaseInsensitiveContains(query)
                || (article.description?.localizedCaseInsensitiveContains(query) ?? false)
                || (article.source?.name.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// Starts with the disk snapshot so repeat launches feel immediate, then asks
    /// the server for fresh page one. This is the key offline-first flow.
    func start() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.loadBookmarks()

            let cached = await self.repository.cachedHeadlines()
            guard !Task.isCancelled else { return }
            self.allArticles = cached
            self.state = cached.isEmpty ? .loading : .content(isOffline: true)
            self.notifyChange()

            await self.loadPage(1, replacingFeed: true)
        }
    }

    /// Cancels any old refresh and begins again at page one.
    func refresh() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.loadPage(1, replacingFeed: true)
        }
    }

    /// Retries the operation represented by the current error screen.
    func retry() {
        refresh()
    }

    /// Requests the next page when the user reaches the last few visible rows.
    func loadNextPageIfNeeded(visibleIndex: Int) {
        let triggerIndex = max(displayedArticles.count - 4, 0)
        guard mode == .all,
              filterText.isEmpty,
              visibleIndex >= triggerIndex,
              !isLoadingNextPage,
              allArticles.count < totalResults else { return }

        isLoadingNextPage = true
        notifyChange()
        let nextPage = currentPage + 1
        loadTask = Task { [weak self] in
            await self?.loadPage(nextPage, replacingFeed: false)
        }
    }

    /// Stops network and backoff work when the screen leaves memory.
    func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        isLoadingNextPage = false
    }

    /// Returns bookmark state in constant time using the already-loaded array.
    func isBookmarked(_ article: Article) -> Bool {
        bookmarkedArticles.contains { $0.id == article.id }
    }

    /// Optimistically updates the heart/bookmark immediately, then persists it.
    func toggleBookmark(_ article: Article) {
        let shouldSave = !isBookmarked(article)

        if shouldSave {
            bookmarkedArticles.insert(article, at: 0)
        } else {
            bookmarkedArticles.removeAll { $0.id == article.id }
        }
        notifyChange()

        Task { [repository] in
            await repository.setBookmarked(shouldSave, article: article)
        }
        onAnnouncement?(L10n.text(shouldSave ? "state.saved" : "state.unsaved"))
    }

    /// Finds the full model for an incoming deep link when it is already known.
    func article(matchingURL url: URL) -> Article? {
        (allArticles + bookmarkedArticles).first { $0.url == url.absoluteString }
    }

    /// Loads bookmarks once at startup or after an integration test changes disk.
    func loadBookmarks() async {
        bookmarkedArticles = await repository.bookmarks()
        notifyChange()
    }

    /// Performs one API page request and translates the result into screen state.
    private func loadPage(_ page: Int, replacingFeed: Bool) async {
        if replacingFeed, allArticles.isEmpty {
            state = .loading
            notifyChange()
        }

        do {
            let result = try await repository.fetchHeadlines(page: page, pageSize: pageSize)
            try Task.checkCancellation()

            if replacingFeed {
                allArticles = unique(result.articles)
            } else {
                allArticles = unique(allArticles + result.articles)
            }
            currentPage = result.page
            totalResults = result.totalResults
            isLoadingNextPage = false
            state = allArticles.isEmpty ? .empty : .content(isOffline: false)
            notifyChange()

            if replacingFeed {
                onAnnouncement?(L10n.text("state.updated"))
            }
        } catch is CancellationError {
            isLoadingNextPage = false
        } catch {
            isLoadingNextPage = false
            if allArticles.isEmpty {
                state = .failed(message: error.localizedDescription)
            } else {
                state = .content(isOffline: true)
                onAnnouncement?(error.localizedDescription)
            }
            notifyChange()
        }
    }

    /// Keeps the first copy of each story while preserving the API's order.
    private func unique(_ articles: [Article]) -> [Article] {
        var seen = Set<String>()
        return articles.filter { seen.insert($0.id).inserted }
    }

    /// A single notification point makes every state change easy to trace.
    private func notifyChange() {
        onChange?()
    }
}
