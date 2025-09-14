//
//  AppConstants.swift
//  News App
//
//  Created by sachin kumar on 14/09/25.
//

class AppConstants {
    var shared = AppConstants()
    private init (){
    }
    static let baseURL = "https://newsapi.org/v2/top-headlines?country=us&category=business"
    static let apiKey = "5e2c60b89d534646b67f980899fc655f"
}
