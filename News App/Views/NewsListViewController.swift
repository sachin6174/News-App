import SwiftUI
import UIKit

/// The main UIKit screen. It owns views and user gestures; the ViewModel owns data
/// and decisions. Keeping that border clear makes both pieces small and testable.
final class NewsListViewController: UIViewController {
    private let viewModel: NewsListViewModel

    private let segmentedControl = UISegmentedControl(items: [
        L10n.text("segment.all"),
        L10n.text("segment.bookmarks")
    ])
    private let offlineLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let stateStack = UIStackView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let stateTitleLabel = UILabel()
    private let stateMessageLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let nextPageSpinner = UIActivityIndicatorView(style: .medium)
    private let searchController = UISearchController(searchResultsController: nil)

    init(viewModel: NewsListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("NewsListViewController is created in Swift, not a storyboard.")
    }

    /// Builds the screen in an easy-to-follow order, binds it, then starts data.
    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
        configureViews()
        buildHierarchyAndConstraints()
        bindViewModel()
        viewModel.start()
    }

    /// Stops a URLSession task or retry sleep if the whole controller is released.
    deinit {
        viewModel.cancelLoading()
    }

    /// Configures the large title and searchable navigation bar.
    private func configureNavigation() {
        title = L10n.text("app.title")
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = L10n.text("search.placeholder")
        searchController.searchBar.searchTextField.accessibilityIdentifier = "news.search"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    /// Applies fonts, colours, identifiers, delegates, and action targets.
    private func configureViews() {
        view.backgroundColor = .systemBackground

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.accessibilityIdentifier = "news.segment"
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        offlineLabel.text = L10n.text("state.offline")
        offlineLabel.font = .preferredFont(forTextStyle: .caption1)
        offlineLabel.adjustsFontForContentSizeCategory = true
        offlineLabel.textAlignment = .center
        offlineLabel.textColor = .label
        offlineLabel.backgroundColor = .systemOrange.withAlphaComponent(0.22)
        offlineLabel.accessibilityIdentifier = "news.offlineBanner"
        offlineLabel.isHidden = true

        tableView.register(
            NewsArticleCell.self,
            forCellReuseIdentifier: NewsArticleCell.reuseIdentifier
        )
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 140
        tableView.keyboardDismissMode = .onDrag
        tableView.accessibilityIdentifier = "news.list"

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = refreshControl

        stateStack.axis = .vertical
        stateStack.alignment = .center
        stateStack.spacing = 12
        stateStack.isLayoutMarginsRelativeArrangement = true
        stateStack.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        stateTitleLabel.font = .preferredFont(forTextStyle: .title2)
        stateTitleLabel.adjustsFontForContentSizeCategory = true
        stateTitleLabel.numberOfLines = 0
        stateTitleLabel.textAlignment = .center
        stateTitleLabel.accessibilityTraits.insert(.header)

        stateMessageLabel.font = .preferredFont(forTextStyle: .body)
        stateMessageLabel.adjustsFontForContentSizeCategory = true
        stateMessageLabel.numberOfLines = 0
        stateMessageLabel.textAlignment = .center
        stateMessageLabel.textColor = .secondaryLabel

        retryButton.setTitle(L10n.text("action.retry"), for: .normal)
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        retryButton.accessibilityIdentifier = "news.retry"
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        stateStack.addArrangedSubview(activityIndicator)
        stateStack.addArrangedSubview(stateTitleLabel)
        stateStack.addArrangedSubview(stateMessageLabel)
        stateStack.addArrangedSubview(retryButton)
    }

    /// Adds every view and describes its position with programmatic Auto Layout.
    private func buildHierarchyAndConstraints() {
        [segmentedControl, offlineLabel, tableView, stateStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            offlineLabel.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            offlineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            offlineLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),

            tableView.topAnchor.constraint(equalTo: offlineLabel.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stateStack.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            stateStack.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            stateStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            stateStack.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }

    /// Converts ViewModel callbacks into a render and VoiceOver announcements.
    private func bindViewModel() {
        viewModel.onChange = { [weak self] in
            self?.render()
        }
        viewModel.onAnnouncement = { message in
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    /// Makes every visual element a pure reflection of the latest state.
    private func render() {
        tableView.reloadData()
        tableView.refreshControl?.endRefreshing()
        offlineLabel.isHidden = true
        activityIndicator.stopAnimating()
        retryButton.isHidden = true
        stateTitleLabel.text = nil
        stateMessageLabel.text = nil

        // Bookmarks are useful even when the live feed is loading or has failed.
        // Their rows come from a separate Core Data shelf, so the feed's network
        // state must never cover them with an unrelated error screen.
        if viewModel.mode == .bookmarks {
            let bookmarksAreEmpty = viewModel.displayedArticles.isEmpty
            stateStack.isHidden = !bookmarksAreEmpty
            tableView.isHidden = bookmarksAreEmpty
            stateMessageLabel.text = bookmarksAreEmpty
                ? L10n.text("state.empty.bookmarks")
                : nil
            nextPageSpinner.stopAnimating()
            tableView.tableFooterView = UIView(frame: .zero)
            return
        }

        switch viewModel.state {
        case .idle, .loading:
            stateStack.isHidden = false
            tableView.isHidden = true
            activityIndicator.startAnimating()
            stateMessageLabel.text = L10n.text("state.loading")
        case .content(let isOffline):
            offlineLabel.isHidden = !isOffline
            let filteredListIsEmpty = viewModel.displayedArticles.isEmpty
            stateStack.isHidden = !filteredListIsEmpty
            tableView.isHidden = filteredListIsEmpty
            if filteredListIsEmpty {
                stateMessageLabel.text = viewModel.mode == .bookmarks
                    ? L10n.text("state.empty.bookmarks")
                    : L10n.text("state.empty")
            }
        case .empty:
            stateStack.isHidden = false
            tableView.isHidden = true
            stateMessageLabel.text = L10n.text("state.empty")
        case .failed(let message):
            stateStack.isHidden = false
            tableView.isHidden = true
            stateTitleLabel.text = L10n.text("error.title")
            stateMessageLabel.text = message
            retryButton.isHidden = false
        }

        if viewModel.isLoadingNextPage {
            nextPageSpinner.startAnimating()
            nextPageSpinner.frame.size.height = 52
            tableView.tableFooterView = nextPageSpinner
        } else {
            nextPageSpinner.stopAnimating()
            tableView.tableFooterView = UIView(frame: .zero)
        }
    }

    /// Switches between normal and saved stories.
    @objc private func segmentChanged() {
        viewModel.mode = segmentedControl.selectedSegmentIndex == 0 ? .all : .bookmarks
    }

    /// Pull-to-refresh always requests a clean page one.
    @objc private func refreshPulled() {
        viewModel.refresh()
    }

    /// The error button repeats the same safe first-page request.
    @objc private func retryTapped() {
        viewModel.retry()
    }

    /// Pushes a SwiftUI screen inside the existing UIKit navigation controller.
    private func showDetail(for article: Article) {
        let detail = ArticleDetailView(
            article: article,
            initiallyBookmarked: viewModel.isBookmarked(article),
            onBookmark: { [weak self] in self?.viewModel.toggleBookmark(article) }
        )
        let host = UIHostingController(rootView: detail)
        navigationController?.pushViewController(host, animated: true)
    }

    /// Opens a validated app deep link and returns whether it belonged to us.
    @discardableResult
    func openDeepLink(_ deepLink: URL) -> Bool {
        guard let articleURL = DeepLinkRouter.articleURL(from: deepLink) else { return false }
        let article = viewModel.article(matchingURL: articleURL) ?? Article(
            source: nil,
            author: nil,
            title: L10n.text("detail.shared.title"),
            description: nil,
            url: articleURL.absoluteString,
            urlToImage: nil,
            publishedAt: "",
            content: nil
        )
        showDetail(for: article)
        return true
    }
}

extension NewsListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.displayedArticles.count
    }

    /// Dequeues a reusable cell and gives its bookmark closure back to the model.
    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: NewsArticleCell.reuseIdentifier,
            for: indexPath
        ) as? NewsArticleCell else {
            return UITableViewCell()
        }

        let article = viewModel.displayedArticles[indexPath.row]
        cell.accessibilityIdentifier = "article.cell.\(indexPath.row)"
        cell.configure(
            article: article,
            isBookmarked: viewModel.isBookmarked(article),
            onBookmark: { [weak self] in self?.viewModel.toggleBookmark(article) }
        )
        return cell
    }

    /// Selecting a row opens the native detail view instead of leaving the app.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showDetail(for: viewModel.displayedArticles[indexPath.row])
    }

    /// This prefetch-like trigger loads page two before the user reaches the end.
    func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        viewModel.loadNextPageIfNeeded(visibleIndex: indexPath.row)
    }
}

extension NewsListViewController: UISearchResultsUpdating {
    /// Search remains local and instant; it never wastes an API request per letter.
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.filterText = searchController.searchBar.text ?? ""
    }
}
