import WidgetKit

/// Mirrors `WidgetHeadline` from the main app target (News App/Models/Services/
/// WidgetDataWriter.swift). Duplicated intentionally rather than shared as one
/// source file, so this extension target has no build dependency on the app
/// target — see docs/WIDGET_SETUP.md for why and how these two targets share
/// data instead (an App Group, not shared source).
struct WidgetHeadline: Codable {
    let title: String
    let sourceName: String?
    let url: String
}

/// One timeline entry: the headlines to show and whether they are the built-in
/// placeholder (shown before the app has ever written real data).
struct NewslyWidgetEntry: TimelineEntry {
    let date: Date
    let headlines: [WidgetHeadline]
    let isPlaceholderData: Bool
}
