//
//  NewsTableViewCell.swift
//  News App
//
//  Created by sachin kumar on 15/09/25.
//

import UIKit
import SDWebImage

class NewsTableViewCell: UITableViewCell {
    static let identifier = "NewsTableViewCell"

    @IBOutlet weak var newsImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var bookmarkButton: UIButton!

    var article: Article?
    var bookmarkTapped: ((Article) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    private func setupUI() {
        newsImageView.contentMode = .scaleAspectFill
        newsImageView.clipsToBounds = true
        newsImageView.layer.cornerRadius = 8

        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.numberOfLines = 2

        descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = .systemGray
        descriptionLabel.numberOfLines = 3

        bookmarkButton.setImage(UIImage(systemName: "bookmark"), for: .normal)
        bookmarkButton.setImage(UIImage(systemName: "bookmark.fill"), for: .selected)
        bookmarkButton.tintColor = .systemBlue
    }

    func configure(with article: Article, isBookmarked: Bool = false) {
        self.article = article
        titleLabel.text = article.title
        descriptionLabel.text = article.description ?? "No description available"
        bookmarkButton.isSelected = isBookmarked

        if let imageURL = article.urlToImage, let url = URL(string: imageURL) {
            newsImageView.sd_setImage(with: url, placeholderImage: UIImage(systemName: "photo"))
        } else {
            newsImageView.image = UIImage(systemName: "photo")
        }
    }

    @IBAction func bookmarkButtonTapped(_ sender: UIButton) {
        guard let article = article else { return }
        bookmarkTapped?(article)
        sender.isSelected.toggle()
    }
}