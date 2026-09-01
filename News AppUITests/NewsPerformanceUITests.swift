import XCTest

final class NewsPerformanceUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Xcode records launch duration over repeated deterministic fixture launches.
    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-testing"]
            app.launch()
        }
    }

    /// Measures animation hitches while enough rows are scrolled to trigger page two.
    @MainActor
    func testScrollingPerformance() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let list = app.tables["news.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 3))

        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
            list.swipeUp(velocity: .fast)
            list.swipeUp(velocity: .fast)
            list.swipeDown(velocity: .fast)
        }
    }
}
