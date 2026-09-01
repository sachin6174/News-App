import XCTest

final class CriticalUserJourneysUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
    }

    /// Covers launch, deterministic REST replacement, search, detail, and bookmark.
    @MainActor
    func testSearchOpenAndBookmarkStory() {
        app.launch()
        let firstCell = app.cells["article.cell.0"]
        XCTAssertTrue(firstCell.waitForExistence(timeout: 3))

        let searchField = app.searchFields["news.search"]
        searchField.tap()
        searchField.typeText("Swift")
        XCTAssertEqual(app.cells.matching(identifier: "article.cell.0").count, 1)

        firstCell.tap()
        XCTAssertTrue(app.buttons["detail.bookmark"].waitForExistence(timeout: 2))
        app.buttons["detail.bookmark"].tap()
        XCTAssertTrue(app.buttons["detail.readFullStory"].exists)
    }

    /// Proves the retry/error state instead of relying on an unpredictable outage.
    @MainActor
    func testNetworkErrorShowsRetryState() {
        app.launchArguments = ["--ui-testing-error"]
        app.launch()

        XCTAssertTrue(app.buttons["news.retry"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Could Not Load News"].exists)
    }

    /// Exercises the actual route parser and UIKit-to-SwiftUI navigation handoff.
    @MainActor
    func testDeepLinkOpensDetail() {
        app.launchEnvironment["UITEST_DEEP_LINK"] =
            "newsapp://article?url=https%3A%2F%2Fexample.com%2Fstories%2F1"
        app.launch()

        XCTAssertTrue(app.buttons["detail.readFullStory"].waitForExistence(timeout: 3))
    }

    /// Runs Apple's automated checks for missing labels, small hit targets, and more.
    @MainActor
    func testAccessibilityAudit() throws {
        app.launch()
        XCTAssertTrue(app.cells["article.cell.0"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit()
    }
}
