//
//  ImageLoader.swift
//  News App
//
//  A tiny image loader with in-memory caching.
//

import UIKit

final class ImageLoader {
    static let shared = ImageLoader()
    private init() {}

    private let cache = NSCache<NSString, UIImage>()

    func load(_ urlString: String?, into imageView: UIImageView, placeholder: UIImage? = UIImage(systemName: "photo")) {
        imageView.image = placeholder

        guard let urlString = urlString, let url = URL(string: urlString) else { return }

        if let cached = cache.object(forKey: urlString as NSString) {
            imageView.image = cached
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self, weak imageView] data, _, error in
            guard let data = data, error == nil, let image = UIImage(data: data) else { return }
            self?.cache.setObject(image, forKey: urlString as NSString)
            DispatchQueue.main.async {
                // Simple fade-in for a nicer feel
                UIView.transition(with: imageView ?? UIImageView(), duration: 0.2, options: .transitionCrossDissolve) {
                    imageView?.image = image
                }
            }
        }.resume()
    }
}

