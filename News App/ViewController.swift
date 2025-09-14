//
//  ViewController.swift
//  News App
//
//  Created by sachin kumar on 13/09/25.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        // Example: Fetch top US business headlines
        APIService.shared.request(
            endpoint: AppConstants.baseURL,
            queryItems: [
                URLQueryItem(name: "country", value: "us"),
                URLQueryItem(name: "category", value: "business")
            ],
            responseType: NewsResponse.self
        ) { result in
            switch result {
            case .success(let response):
                print("Got \(response.articles.count) articles")
                for article in response.articles {
                    print("📰 \(article.title)")
                }
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }

    }


}

