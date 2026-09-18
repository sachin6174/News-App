import Foundation

/// A NewsAPI top-headlines category the reader can choose to follow.
///
/// Raw values match NewsAPI's own category names exactly, so a case can be sent
/// straight through as a query item without a translation table. `general` is
/// intentionally left out: the app's default "Top" feed already covers it, so a
/// `general` chip would just be a confusing duplicate of "Top".
enum Topic: String, CaseIterable, Codable, Hashable, Sendable {
    case business
    case entertainment
    case health
    case science
    case sports
    case technology

    /// A small starter set so a first launch already has something to show
    /// instead of an empty topic bar.
    static let defaultFollowed: [Topic] = [.technology, .business]

    var displayName: String {
        L10n.text("topic.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .business: return "chart.line.uptrend.xyaxis"
        case .entertainment: return "theatermasks"
        case .health: return "heart.text.square"
        case .science: return "atom"
        case .sports: return "sportscourt"
        case .technology: return "cpu"
        }
    }
}
