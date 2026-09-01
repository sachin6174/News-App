import XCTest
@testable import News_App

final class DeepLinkRouterTests: XCTestCase {
    func testValidArticleDeepLinkReturnsHTTPSDestination() throws {
        let link = try XCTUnwrap(URL(string: "newsapp://article?url=https%3A%2F%2Fexample.com%2Fstory"))
        XCTAssertEqual(
            DeepLinkRouter.articleURL(from: link)?.absoluteString,
            "https://example.com/story"
        )
    }

    func testUnsafeDestinationIsRejected() throws {
        let link = try XCTUnwrap(URL(string: "newsapp://article?url=javascript%3Aalert(1)"))
        XCTAssertNil(DeepLinkRouter.articleURL(from: link))
    }
}
