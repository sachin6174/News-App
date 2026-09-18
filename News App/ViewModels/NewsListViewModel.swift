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

    /// Topics the reader follows, and — when one is selected — its own small,
    /// unpaginated feed. These stay separate from `allArticles`/`state` above
    /// so the general feed's tested pagination and offline-cache behaviour is
    /// never touched by this feature.
    private(set) var followedTopics: [Topic] = []
    private(set) var selectedTopic: Topic?
    private(set) var topicArticles: [Article] = []
    private(set) var topicState: State = .idle

    var mode: Mode = .all {
        didSet { notifyChange() }
    }
    var filterText = "" {
        didSet { notifyChange() }
    }

    var onChange: (() -> Void)?
    var onAnnouncement: ((String) -> Void)?

    private let repository: NewsRepository
    private let topicPreferences: TopicPreferencesStore
    private let pageSize: Int
    private var currentPage = 0
    private var totalResults = Int.max
    private var loadTask: Task<Void, Never>?
    private var topicLoadTask: Task<Void, Never>?

    init(
        repository: NewsRepository = DefaultNewsRepository(),
        topicPreferences: TopicPreferencesStore = .shared,
        pageSize: Int = 20
    ) {
        self.repository = repository
        self.topicPreferences = topicPreferences
        self.pageSize = pageSize
    }

    /// The exact list the table should show after segment and search filtering.
    var displayedArticles: [Article] {
        let base: [Article]
        switch mode {
        case .bookmarks:
            base = bookmarkedArticles
        case .all:
            base = selectedTopic == nil ? allArticles : topicArticles
        }
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }

        return base.filter { article in
            article.title.localizedCaseInsensitiveContains(query)
                || (article.description?.localizedCaseInsensitiveContains(query) ?? false)
                || (article.source?.name.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// Which state the feed screen should render: the general feed's own state,
    /// or the selected topic's — without disturbing either one's storage above.
    var currentFeedState: State {
        selectedTopic == nil ? state : topicState
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
        topicLoadTask?.cancel()
        topicLoadTask = nil
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

    /// Reloads the followed-topics list from disk. Call after the Topics screen
    /// changes it, and once during `start()` so the chip bar has data from the
    /// very first render.
    func refreshFollowedTopics() {
        followedTopics = topicPreferences.followedTopics
        notifyChange()
    }

    /// Follows or unfollows one topic and persists the change immediately.
    func setTopic(_ topic: Topic, followed: Bool) {
        topicPreferences.setFollowed(topic, followed: followed)
        refreshFollowedTopics()
        if !followed, selectedTopic == topic {
            selectTopic(nil)
        }
    }

    /// Switches which feed is showing. `nil` returns to the already-loaded
    /// general feed; any `Topic` triggers its own single-page fetch.
    func selectTopic(_ topic: Topic?) {
        guard selectedTopic != topic else { return }
        topicLoadTask?.cancel()
        selectedTopic = topic
        notifyChange()
        guard let topic else { return }
        loadTopic(topic)
    }

    /// Shows any cached copy of a topic immediately, then refreshes it live —
    /// the same offline-first shape `start()` uses for the general feed.
    private func loadTopic(_ topic: Topic) {
        let cached = TopicArticleCache.shared.articles(for: topic)
        topicArticles = cached
        topicState = cached.isEmpty ? .loading : .content(isOffline: true)
        notifyChange()

        topicLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let articles = try await self.repository.fetchTopicHeadlines(topic)
                guard !Task.isCancelled, self.selectedTopic == topic else { return }
                self.topicArticles = articles
                self.topicState = articles.isEmpty ? .empty : .content(isOffline: false)
                self.notifyChange()
            } catch is CancellationError {
                // A newer topic switch already superseded this request.
            } catch {
                guard self.selectedTopic == topic else { return }
                if self.topicArticles.isEmpty {
                    self.topicState = .failed(message: error.localizedDescription)
                } else {
                    self.topicState = .content(isOffline: true)
                }
                self.notifyChange()
            }
        }
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
