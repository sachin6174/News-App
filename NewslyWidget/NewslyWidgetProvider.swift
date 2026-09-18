import WidgetKit

/// Reads the small JSON snapshot the main app writes after every successful
/// page-one fetch (`WidgetDataWriter` in the app target) and turns it into
/// timeline entries.
struct NewslyWidgetProvider: TimelineProvider {
    /// Must match `WidgetDataWriter.appGroupIdentifier` in the main app target,
    /// and the App Group ID you add to both targets' capabilities in Xcode.
    /// See docs/WIDGET_SETUP.md.
    static let appGroupIdentifier = "group.in.sachinserver.News-App"
    private static let snapshotKey = "widget.topHeadlines"

    func placeholder(in context: Context) -> NewslyWidgetEntry {
        NewslyWidgetEntry(date: Date(), headlines: Self.placeholderHeadlines, isPlaceholderData: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (NewslyWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NewslyWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // The app also nudges WidgetKit directly (`WidgetCenter.reloadAllTimelines()`)
        // right after it writes fresh data, so this fallback timer just guarantees
        // a periodic check even if that direct nudge is ever missed.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 45, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> NewslyWidgetEntry {
        guard let sharedDefaults = UserDefaults(suiteName: Self.appGroupIdentifier),
              let data = sharedDefaults.data(forKey: Self.snapshotKey),
              let headlines = try? JSONDecoder().decode([WidgetHeadline].self, from: data),
              !headlines.isEmpty else {
            return NewslyWidgetEntry(date: Date(), headlines: Self.placeholderHeadlines, isPlaceholderData: true)
        }
        return NewslyWidgetEntry(date: Date(), headlines: headlines, isPlaceholderData: false)
    }

    private static let placeholderHeadlines = [
        WidgetHeadline(title: "Open Newsly to load today's headlines", sourceName: nil, url: "")
    ]
}
