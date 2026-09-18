import Foundation

/// A small per-topic offline snapshot so a followed topic still shows the last
/// stories it had even without a connection.
///
/// This intentionally stays outside Core Data. Topic snapshots are short-lived,
/// there are at most a handful of them, and a plain JSON blob in `UserDefaults`
/// is enough for that — while keeping the well-tested Core Data cache/bookmark
/// model in `DataStoreManager` completely untouched by this feature.
final class TopicArticleCache {
    static let shared = TopicArticleCache()

    private let defaults: UserDefaults
    private let maxArticlesPerTopic = 20

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func articles(for topic: Topic) -> [Article] {
        guard let data = defaults.data(forKey: key(for: topic)),
              let articles = try? JSONDecoder().decode([Article].self, from: data) else {
            return []
        }
        return articles
    }

    func store(_ articles: [Article], for topic: Topic) {
        let limited = Array(articles.prefix(maxArticlesPerTopic))
        guard let data = try? JSONEncoder().encode(limited) else { return }
        defaults.set(data, forKey: key(for: topic))
    }

    private func key(for topic: Topic) -> String {
        "topicCache.\(topic.rawValue)"
    }
}
