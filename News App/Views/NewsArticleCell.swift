import UIKit

/// A fully programmatic table cell. Every position is described with Auto Layout,
/// so there is no hidden storyboard geometry to hunt for when the design changes.
final class NewsArticleCell: UITableViewCell {
    static let reuseIdentifier = "NewsArticleCell"

    private let articleImageView = UIImageView()
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let sourceLabel = UILabel()
    private let bookmarkButton = UIButton(type: .system)

    private var representedArticleID: String?
    private var imageTask: Task<Void, Never>?
    private var bookmarkAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildViewHierarchy()
        configureAppearance()
        activateConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("NewsArticleCell is created in Swift, not from a storyboard.")
    }

    /// Clears old asynchronous work before iOS reuses this cell for another row.
    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        representedArticleID = nil
        bookmarkAction = nil
        articleImageView.image = UIImage(systemName: "newspaper")
    }

    /// Places subviews into a vertical text stack beside the image.
    private func buildViewHierarchy() {
        let textStack = UIStackView(arrangedSubviews: [sourceLabel, titleLabel, summaryLabel])
        textStack.axis = .vertical
        textStack.spacing = 5
        textStack.alignment = .fill

        [articleImageView, textStack, bookmarkButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            articleImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            articleImageView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            articleImageView.widthAnchor.constraint(equalToConstant: 104),
            articleImageView.heightAnchor.constraint(equalToConstant: 104),
            articleImageView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.bottomAnchor),

            textStack.leadingAnchor.constraint(equalTo: articleImageView.trailingAnchor, constant: 12),
            textStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            textStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),

            bookmarkButton.leadingAnchor.constraint(equalTo: textStack.trailingAnchor, constant: 8),
            bookmarkButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            bookmarkButton.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            bookmarkButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            bookmarkButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    /// Applies Dynamic Type fonts, semantic colours, and touch behaviour.
    private func configureAppearance() {
        articleImageView.contentMode = .scaleAspectFill
        articleImageView.clipsToBounds = true
        articleImageView.layer.cornerRadius = 10
        articleImageView.backgroundColor = .secondarySystemBackground
        articleImageView.isAccessibilityElement = true
        articleImageView.accessibilityTraits = .image

        sourceLabel.font = .preferredFont(forTextStyle: .caption1)
        sourceLabel.adjustsFontForContentSizeCategory = true
        sourceLabel.textColor = .secondaryLabel
        // Publisher names can be long. Unlimited lines prevent truncation both in
        // translated text and at the largest accessibility Dynamic Type settings.
        sourceLabel.numberOfLines = 0
        sourceLabel.lineBreakMode = .byWordWrapping

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 3
        titleLabel.accessibilityTraits.insert(.header)

        summaryLabel.font = .preferredFont(forTextStyle: .subheadline)
        summaryLabel.adjustsFontForContentSizeCategory = true
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 3

        bookmarkButton.addTarget(self, action: #selector(bookmarkTapped), for: .touchUpInside)
        bookmarkButton.accessibilityIdentifier = "article.bookmark"
        accessoryType = .disclosureIndicator
        selectionStyle = .default
    }

    /// This method is intentionally separate so every constraint has one home.
    private func activateConstraints() {
        articleImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        bookmarkButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    /// Fills the cell and starts a cancellable image request for this exact story.
    func configure(
        article: Article,
        isBookmarked: Bool,
        onBookmark: @escaping () -> Void
    ) {
        representedArticleID = article.id
        bookmarkAction = onBookmark
        sourceLabel.text = article.source?.name
        titleLabel.text = article.title
        summaryLabel.text = article.description ?? L10n.text("article.no.description")
        updateBookmarkAppearance(isBookmarked: isBookmarked)

        articleImageView.image = UIImage(systemName: "newspaper")
        articleImageView.accessibilityLabel = String(
            format: L10n.text("image.article"),
            article.title
        )

        imageTask?.cancel()
        imageTask = Task { [weak self] in
            let image = await CachedImageLoader.shared.image(for: article.urlToImage)
            guard !Task.isCancelled,
                  self?.representedArticleID == article.id,
                  let image else { return }
            self?.articleImageView.image = image
        }
    }

    /// Gives both sighted and VoiceOver users the same bookmark state.
    private func updateBookmarkAppearance(isBookmarked: Bool) {
        let symbol = isBookmarked ? "bookmark.fill" : "bookmark"
        bookmarkButton.setImage(UIImage(systemName: symbol), for: .normal)
        bookmarkButton.accessibilityLabel = L10n.text(
            isBookmarked ? "action.remove.bookmark" : "action.bookmark"
        )
        bookmarkButton.accessibilityHint = L10n.text(
            isBookmarked ? "bookmark.accessibility.saved" : "bookmark.accessibility.unsaved"
        )
    }

    /// Forwards the tap without letting a reusable view own business logic.
    @objc private func bookmarkTapped() {
        bookmarkAction?()
    }
}
