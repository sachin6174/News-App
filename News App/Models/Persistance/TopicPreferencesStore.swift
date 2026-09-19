import Foundation

/// Persists which topics the reader wants to follow.
///
/// Backed by `UserDefaults` rather than Core Data on purpose: the list is tiny
/// (at most a handful of category names), it has no relationships to model, and
/// keeping it out of Core Data means the already-tested cache/bookmark schema in
/// `DataStoreManager` never has to change to support this feature.
final class TopicPreferencesStore {
    static let shared = TopicPreferencesStore()

    private let defaults: UserDefaults
    private let followedKey = "topicPreferences.followed"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Followed topics in a stable order (the order `Topic.allCases` declares
    /// them), so the chip bar does not reshuffle itself between launches.
    var followedTopics: [Topic] {
        guard let rawValues = defaults.stringArray(forKey: followedKey) else {
            return Topic.defaultFollowed
        }
        let saved = Set(rawValues.compactMap(Topic.init(rawValue:)))
        return Topic.allCases.filter(saved.contains)
    }

    func isFollowing(_ topic: Topic) -> Bool {
        followedTopics.contains(topic)
    }

    func setFollowed(_ topic: Topic, followed: Bool) {
        var current = Set(followedTopics)
        if followed {
            current.insert(topic)
        } else {
            current.remove(topic)
        }
        defaults.set(current.map(\.rawValue), forKey: followedKey)
    }
}
