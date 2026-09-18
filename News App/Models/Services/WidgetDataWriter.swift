import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Publishes a small snapshot of the top headlines to an App Group container so
/// a Home Screen widget extension can read it.
///
/// Safe to call even before a widget target and App Group capability exist in
/// Xcode: `UserDefaults(suiteName:)` simply returns nil until the app has that
/// entitlement, and this type no-ops in that case rather than crashing. See
/// docs/WIDGET_SETUP.md for wiring up the actual widget extension target.
enum WidgetDataWriter {
    /// Must match the App Group identifier you add to both the app target and
    /// the widget extension target's capabilities in Xcode, and the constant of
    /// the same name in the widget's own timeline provider.
    static let appGroupIdentifier = "group.in.sachinserver.News-App"
    private static let snapshotKey = "widget.topHeadlines"
    private static let maxHeadlines = 5

    static func write(topHeadlines articles: [Article]) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        let snapshot = articles.prefix(maxHeadlines).map {
            WidgetHeadline(title: $0.title, sourceName: $0.source?.name, url: $0.url)
        }
        guard let data = try? JSONEncoder().encode(Array(snapshot)) else { return }
        sharedDefaults.set(data, forKey: snapshotKey)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

/// The tiny value the widget extension decodes. Kept intentionally duplicated
/// (not shared source) in the widget target so that target has no build
/// dependency on the main app target — see docs/WIDGET_SETUP.md.
struct WidgetHeadline: Codable {
    let title: String
    let sourceName: String?
    let url: String
}
