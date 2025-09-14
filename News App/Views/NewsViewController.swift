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

    private var allArticles: [Article] = []
    private var bookmarkedArticles: [Article] = []
    private var currentArticles: [Article] = []

    private let dataStoreManager = DataStoreManager.shared
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        fetchNews()
        loadBookmarkedArticles()
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

    private func fetchNews() {
        APIService.shared.request(
            endpoint: AppConstants.baseURL,
            queryItems: [
                URLQueryItem(name: "country", value: "us"),
                URLQueryItem(name: "category", value: "business")
            ],
            responseType: NewsResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.allArticles = response.articles
                    self?.updateCurrentArticles()
                case .failure(let error):
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }

    private func loadBookmarkedArticles() {
        bookmarkedArticles = dataStoreManager.fetchBookmarkedArticles()
        if segmentedControl.selectedSegmentIndex == 1 {
            updateCurrentArticles()
        }
    }

    private func updateCurrentArticles() {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            currentArticles = allArticles
        case 1:
            currentArticles = bookmarkedArticles
        default:
            break
        }
        tableView.reloadData()
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        updateCurrentArticles()
    }

    private func toggleBookmark(for article: Article) {
        if isArticleBookmarked(article) {
            dataStoreManager.removeBookmark(for: article)
            bookmarkedArticles.removeAll { $0.url == article.url }
        } else {
            dataStoreManager.saveBookmark(for: article)
            bookmarkedArticles.append(article)
        }
        updateCurrentArticles()
    }

    private func isArticleBookmarked(_ article: Article) -> Bool {
        return bookmarkedArticles.contains { $0.url == article.url }
    }
}

extension NewsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentArticles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: NewsTableViewCell.identifier, for: indexPath) as? NewsTableViewCell else {
            return UITableViewCell()
        }

        let article = currentArticles[indexPath.row]
        let isBookmarked = isArticleBookmarked(article)

        cell.configure(with: article, isBookmarked: isBookmarked)
        cell.bookmarkTapped = { [weak self] article in
            self?.toggleBookmark(for: article)
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let article = currentArticles[indexPath.row]

        if let url = URL(string: article.url) {
            UIApplication.shared.open(url)
        }
    }
}
