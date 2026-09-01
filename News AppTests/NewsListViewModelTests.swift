import XCTest
@testable import News_App

@MainActor
final class NewsListViewModelTests: XCTestCase {
    /// Search checks title, description, and source without contacting the server.
    func testSearchFiltersVisibleArticles() async {
        let repository = MockNewsRepository(
            pages: [1: NewsPage(articles: TestData.articles, page: 1, totalResults: 2)]
        )
        let viewModel = NewsListViewModel(repository: repository)
        let loaded = expectation(description: "Fresh page appears")
        viewModel.onChange = {
            if viewModel.allArticles.count == 2 { loaded.fulfill() }
        }

        viewModel.start()
        await fulfillment(of: [loaded], timeout: 1)
        viewModel.filterText = "swift"

        XCTAssertEqual(viewModel.displayedArticles.map(\.title), ["Swift concurrency explained"])
    }

    /// A failed refresh keeps a disk snapshot visible and marks it as offline.
    func testCachedStoriesRemainVisibleWhenNetworkFails() async {
        let repository = MockNewsRepository(
            pages: [:],
            cached: [TestData.articles[0]],
            error: URLError(.notConnectedToInternet)
        )
        let viewModel = NewsListViewModel(repository: repository)
        let offline = expectation(description: "Offline content appears")
        offline.assertForOverFulfill = false
        viewModel.onChange = {
            if viewModel.state == .content(isOffline: true) { offline.fulfill() }
        }

        viewModel.start()
        await fulfillment(of: [offline], timeout: 1)

        XCTAssertEqual(viewModel.displayedArticles.count, 1)
        XCTAssertEqual(viewModel.state, .content(isOffline: true))
    }

    /// Scrolling near the end asks for page two and joins it without duplicates.
    func testPaginationAppendsNextPage() async {
        let pageOne = NewsPage(articles: [TestData.articles[0]], page: 1, totalResults: 2)
        let pageTwo = NewsPage(articles: [TestData.articles[1]], page: 2, totalResults: 2)
        let repository = MockNewsRepository(pages: [1: pageOne, 2: pageTwo])
        let viewModel = NewsListViewModel(repository: repository, pageSize: 1)
        let firstPage = expectation(description: "Page one")
        viewModel.onChange = {
            if viewModel.allArticles.count == 1 { firstPage.fulfill() }
        }
        viewModel.start()
        await fulfillment(of: [firstPage], timeout: 1)

        let secondPage = expectation(description: "Page two")
        viewModel.onChange = {
            if viewModel.allArticles.count == 2 { secondPage.fulfill() }
        }
        viewModel.loadNextPageIfNeeded(visibleIndex: 0)
        await fulfillment(of: [secondPage], timeout: 1)

        XCTAssertEqual(viewModel.allArticles.map(\.id), TestData.articles.map(\.id))
    }

    /// Bookmark UI updates immediately and the repository receives the final state.
    func testBookmarkTogglePersistsDesiredState() async {
        let repository = MockNewsRepository(pages: [:])
        let viewModel = NewsListViewModel(repository: repository)
        let article = TestData.articles[0]

        viewModel.toggleBookmark(article)
        XCTAssertTrue(viewModel.isBookmarked(article))

        var saved: [Article] = []
        for _ in 0..<20 where saved.isEmpty {
            await Task.yield()
            saved = await repository.bookmarks()
        }
        XCTAssertEqual(saved.map(\.id), [article.id])
    }
}

/// An actor makes this fake safe even when production code awaits it off-main.
private actor MockNewsRepository: NewsRepository {
    let pages: [Int: NewsPage]
    let cached: [Article]
    let error: Error?
    var saved: [Article]

    init(
        pages: [Int: NewsPage],
        cached: [Article] = [],
        saved: [Article] = [],
        error: Error? = nil
    ) {
        self.pages = pages
        self.cached = cached
        self.saved = saved
        self.error = error
    }

    func fetchHeadlines(page: Int, pageSize: Int) async throws -> NewsPage {
        if let error { throw error }
        return pages[page] ?? NewsPage(articles: [], page: page, totalResults: 0)
    }

    func cachedHeadlines() async -> [Article] { cached }
    func bookmarks() async -> [Article] { saved }

    func setBookmarked(_ isBookmarked: Bool, article: Article) async {
        saved.removeAll { $0.id == article.id }
        if isBookmarked { saved.append(article) }
    }
}

enum TestData {
    static let articles = [
        Article(
            source: Source(id: "one", name: "Developer Daily"),
            author: "A. Reporter",
            title: "Swift concurrency explained",
            description: "Learn small and safe tasks.",
            url: "https://example.com/swift",
            urlToImage: nil,
            publishedAt: "2026-01-01T00:00:00Z",
            content: nil
        ),
        Article(
            source: Source(id: "two", name: "World Wire"),
            author: nil,
            title: "A second headline",
            description: "Pagination test story.",
            url: "https://example.com/two",
            urlToImage: nil,
            publishedAt: "2026-01-02T00:00:00Z",
            content: nil
        )
    ]
}
