//
//  NewsViewController.swift
//  News App
//
//  Created by sachin kumar on 15/09/25.
//

import UIKit

class NewsViewController: UIViewController {

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!

    private let viewModel = NewsViewModel()
    private let searchController = UISearchController(searchResultsController: nil)
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        bindViewModel()
        configureSearch()
        configureRefreshControl()
        viewModel.loadBookmarks()
        viewModel.fetchNews()
    }

    private func setupUI() {
        title = "News"
        navigationController?.navigationBar.prefersLargeTitles = true

        segmentedControl.setTitle("All", forSegmentAt: 0)
        segmentedControl.setTitle("Bookmarked", forSegmentAt: 1)
        segmentedControl.selectedSegmentIndex = 0
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120

        let nib = UINib(nibName: NewsTableViewCell.identifier, bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: NewsTableViewCell.identifier)
    }

    private func bindViewModel() {
        viewModel.onChange = { [weak self] in
            self?.tableView.reloadData()
        }
    }

    private func configureSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search articles"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }

    private func configureRefreshControl() {
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = refresh
    }

    @objc private func refreshPulled() {
        viewModel.refresh { [weak self] _ in
            self?.tableView.refreshControl?.endRefreshing()
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        viewModel.mode = sender.selectedSegmentIndex == 0 ? .all : .bookmarks
        viewModel.onChange?()
    }

    private func toggleBookmark(for article: Article) {
        viewModel.toggleBookmark(for: article)
    }

    private func isArticleBookmarked(_ article: Article) -> Bool {
        return viewModel.isBookmarked(article)
    }
}

extension NewsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.displayedArticles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: NewsTableViewCell.identifier, for: indexPath) as? NewsTableViewCell else {
            return UITableViewCell()
        }

        let article = viewModel.displayedArticles[indexPath.row]
        let isBookmarked = viewModel.isBookmarked(article)

        cell.configure(with: article, isBookmarked: isBookmarked)
        cell.bookmarkTapped = { [weak self] article in
            self?.toggleBookmark(for: article)
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let article = viewModel.displayedArticles[indexPath.row]

        if let url = URL(string: article.url) {
            UIApplication.shared.open(url)
        }
    }
}

extension NewsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.filterText = searchController.searchBar.text ?? ""
    }
}
