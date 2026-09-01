import Foundation

/// Chooses production or deterministic test dependencies in one obvious place.
enum AppEnvironment {
    static func makeRepository(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> NewsRepository {
        if arguments.contains("--ui-testing-error") {
            return FixtureNewsRepository(alwaysFails: true)
        }
        if arguments.contains("--ui-testing") {
            return FixtureNewsRepository(alwaysFails: false)
        }
        return DefaultNewsRepository()
    }
}

/// A tiny fake used only when XCUITest passes a launch argument.
actor FixtureNewsRepository: NewsRepository {
    private let alwaysFails: Bool
    private var savedArticles: [Article] = []

    init(alwaysFails: Bool) {
        self.alwaysFails = alwaysFails
    }

    /// Produces stable pages, including enough rows to exercise pagination.
    func fetchHeadlines(page: Int, pageSize: Int) async throws -> NewsPage {
        if alwaysFails {
            throw URLError(.notConnectedToInternet)
        }

        let all = (1...32).map { number in
            Article(
                source: Source(id: "fixture", name: "Test News"),
                author: number.isMultiple(of: 2) ? "Sample Reporter" : nil,
                title: number == 1 ? "Swift makes simple apps safer" : "Test headline \(number)",
                description: "A stable local story used by automated tests.",
                url: "https://example.com/stories/\(number)",
                urlToImage: nil,
                publishedAt: "2026-01-01T12:00:00Z",
                content: nil
            )
        }
        let lower = min((page - 1) * pageSize, all.count)
        let upper = min(lower + pageSize, all.count)
        return NewsPage(
            articles: Array(all[lower..<upper]),
            page: page,
            totalResults: all.count
        )
    }

    func cachedHeadlines() async -> [Article] { [] }
    func bookmarks() async -> [Article] { savedArticles }

    func setBookmarked(_ isBookmarked: Bool, article: Article) async {
        savedArticles.removeAll { $0.id == article.id }
        if isBookmarked { savedArticles.append(article) }
    }
}
