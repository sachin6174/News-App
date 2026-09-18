import SwiftUI
import WidgetKit

struct NewslyWidget: Widget {
    let kind = "NewslyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NewslyWidgetProvider()) { entry in
            NewslyWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Top Headlines")
        .description("Shows the latest headlines from Newsly.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct NewslyWidgetBundle: WidgetBundle {
    var body: some Widget {
        NewslyWidget()
    }
}
