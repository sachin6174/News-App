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

        let newsVC = NewsViewController()
        let navController = UINavigationController(rootViewController: newsVC)

        addChild(navController)
        view.addSubview(navController.view)
        navController.view.frame = view.bounds
        navController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navController.didMove(toParent: self)
    }
}

