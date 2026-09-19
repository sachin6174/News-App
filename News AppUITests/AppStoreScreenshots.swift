import XCTest

/// Drives the real app against live data and writes App Store screenshots to
/// disk. Not part of the regular suite: it needs the network and is run
/// explicitly with `-only-testing:` when store assets are being refreshed.
///
/// Screenshots land in `SCREENSHOT_DIR` when the test host passes one through,
/// and otherwise in `outputDirectory` below. A build setting of the same name
/// does not reach the runner's environment, so the fallback is what normally
/// applies.
final class AppStoreScreenshots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // No --ui-testing: these shots must show real headlines, not fixtures.
        app.launch()
    }

    func testCaptureStoreScreenshots() {
        let firstCell = app.cells["article.cell.0"]
        XCTAssertTrue(firstCell.waitForExistence(timeout: 30), "headlines never loaded")
        // Let remote images finish decoding so no cell renders as a grey block.
        sleep(6)
        capture("01-headlines")

        // Topic feed.
        let technology = app.buttons["topic.chip.technology"]
        if technology.waitForExistence(timeout: 5) {
            technology.tap()
            sleep(6)
            capture("02-topics")
            app.buttons["topic.chip.top"].tap()
            sleep(4)
        }

        // Article detail.
        let cell = app.cells["article.cell.0"]
        if cell.waitForExistence(timeout: 10) {
            cell.tap()
            XCTAssertTrue(app.buttons["detail.bookmark"].waitForExistence(timeout: 15))
            sleep(3)
            capture("03-article")

            // Bookmark it so the bookmarks tab has something to show.
            app.buttons["detail.bookmark"].tap()
            sleep(1)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(3)
        }

        // Bookmarks.
        let segment = app.segmentedControls["news.segment"]
        if segment.waitForExistence(timeout: 5), segment.buttons.count > 1 {
            segment.buttons.element(boundBy: 1).tap()
            sleep(3)
            capture("04-bookmarks")
        }
    }

    /// The runner is sandboxed inside the simulator, so this is the simulator's
    /// own tmp — readable from the host at
    /// ~/Library/Developer/CoreSimulator/Devices/<UDID>/data/tmp.
    private var outputDirectory: String {
        ProcessInfo.processInfo.environment["SCREENSHOT_DIR"]
            ?? NSTemporaryDirectory()
    }

    private func capture(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let dir = outputDirectory
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            print("WROTE \(url.path)")
        } catch {
            XCTFail("could not write \(url.path): \(error)")
        }
    }
}
