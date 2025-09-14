import XCTest
@testable import News_App

final class NewsViewModelTests: XCTestCase {
    func testFilteringByTitle() {
        let vm = NewsViewModel()
        vm.allArticles = [
            Article(source: nil, author: nil, title: "Apple launches iPhone", description: nil, url: "https://a", urlToImage: nil, publishedAt: "2024-09-10T10:00:00Z", content: nil),
            Article(source: nil, author: nil, title: "Google news today", description: nil, url: "https://b", urlToImage: nil, publishedAt: "2024-09-10T10:00:00Z", content: nil)
        ]
        vm.mode = .all
        vm.filterText = "apple"
        XCTAssertEqual(vm.displayedArticles.count, 1)
        XCTAssertEqual(vm.displayedArticles.first?.title, "Apple launches iPhone")
    }
}

