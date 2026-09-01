import SwiftUI
import UIKit

/// This SwiftUI screen is hosted inside the UIKit navigation controller. It is a
/// small, practical example of adopting SwiftUI without rewriting the whole app.
struct ArticleDetailView: View {
    let article: Article
    let initiallyBookmarked: Bool
    let onBookmark: () -> Void

    @State private var isBookmarked: Bool
    @State private var image: UIImage?

    init(
        article: Article,
        initiallyBookmarked: Bool,
        onBookmark: @escaping () -> Void
    ) {
        self.article = article
        self.initiallyBookmarked = initiallyBookmarked
        self.onBookmark = onBookmark
        _isBookmarked = State(initialValue: initiallyBookmarked)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                articleImage

                Text(article.source?.name ?? L10n.text("source.cached"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(article.title)
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                if let author = article.author, !author.isEmpty {
                    Text(String(format: L10n.text("article.by.author"), author))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(article.description ?? L10n.text("article.no.description"))
                    .font(.body)

                bookmarkButton

                if let url = URL(string: article.url), !article.url.isEmpty {
                    Link(destination: url) {
                        Label(L10n.text("action.read.full"), systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("detail.readFullStory")
                }
            }
            .padding()
        }
        .navigationTitle(L10n.text("detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            image = await CachedImageLoader.shared.image(for: article.urlToImage)
        }
    }

    /// Uses a fixed aspect ratio but lets the width follow every device size.
    private var articleImage: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "newspaper")
                    .resizable()
                    .scaledToFit()
                    .padding(50)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel(String(format: L10n.text("image.article"), article.title))
    }

    /// Updates the visual state immediately, then asks UIKit/ViewModel to persist.
    private var bookmarkButton: some View {
        Button {
            isBookmarked.toggle()
            onBookmark()
        } label: {
            Label(
                L10n.text(isBookmarked ? "action.remove.bookmark" : "action.bookmark"),
                systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("detail.bookmark")
    }
}
