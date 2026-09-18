import SwiftUI
import WidgetKit

/// Small widget shows the single top headline; medium shows up to three.
struct NewslyWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NewslyWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Text(entry.headlines.first?.title ?? "No headlines yet")
                .font(.subheadline.bold())
                .lineLimit(4)
            Spacer(minLength: 0)
        }
        .padding()
        .widgetURL(deepLink(for: entry.headlines.first))
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            ForEach(Array(entry.headlines.prefix(3).enumerated()), id: \.offset) { _, headline in
                Text(headline.title)
                    .font(.footnote)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .widgetURL(deepLink(for: entry.headlines.first))
    }

    private var header: some View {
        Label("Newsly", systemImage: "newspaper")
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
    }

    /// Tapping the widget opens the app straight to this story via the same
    /// `newsapp://article?url=` scheme the app already validates and routes —
    /// no widget-specific handling needed on the app side.
    private func deepLink(for headline: WidgetHeadline?) -> URL? {
        guard let headline, !headline.url.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "newsapp"
        components.host = "article"
        components.queryItems = [URLQueryItem(name: "url", value: headline.url)]
        return components.url
    }
}
