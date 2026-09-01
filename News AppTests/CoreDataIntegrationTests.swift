import XCTest
@testable import News_App

final class CoreDataIntegrationTests: XCTestCase {
    /// Proves that real Core Data mapping preserves links and bookmark isolation.
    func testCacheAndBookmarkRoundTrip() async throws {
        let store = DataStoreManager(inMemory: true)
        let article = TestData.articles[0]

        try await store.storeCached([article], page: 1)
        await store.setBookmarked(true, article: article)

        let cached = await store.fetchCachedArticles()
        let bookmarks = await store.fetchBookmarkedArticles()
        XCTAssertEqual(cached.first?.url, article.url)
        XCTAssertEqual(bookmarks.first?.id, article.id)

        try await store.storeCached([], page: 1)
        let emptyCache = await store.fetchCachedArticles()
        let remainingBookmarks = await store.fetchBookmarkedArticles()
        XCTAssertTrue(emptyCache.isEmpty)
        XCTAssertEqual(remainingBookmarks.count, 1)
    }
}
