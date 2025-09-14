//
//  NewsRepository.swift
//  News App
//

import Foundation

protocol NewsRepository {
    func fetchTopHeadlines() async throws -> [Article]
    func cachedHeadlines() -> [Article]
    func bookmarks() -> [Article]
    func toggleBookmark(_ article: Article)
    func isBookmarked(_ article: Article) -> Bool
}

