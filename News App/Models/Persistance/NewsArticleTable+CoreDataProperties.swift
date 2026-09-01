//
//  NewsArticleTable+CoreDataProperties.swift
//  News App
//
//  Created by sachin kumar on 15/09/25.
//
//

import Foundation
import CoreData


extension NewsArticleTable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NewsArticleTable> {
        return NSFetchRequest<NewsArticleTable>(entityName: "NewsArticleTable")
    }

    @NSManaged public var dateInfo: Date?
    @NSManaged public var descriptionData: String?
    @NSManaged public var heading: String?
    @NSManaged public var imageURL: String?
    @NSManaged public var isABookMark: Bool
    @NSManaged public var uuid: UUID?
    @NSManaged public var articleID: String?
    @NSManaged public var articleURL: String?
    @NSManaged public var author: String?
    @NSManaged public var sourceName: String?
    @NSManaged public var publishedAt: String?
    @NSManaged public var contentData: String?
    @NSManaged public var cachedAt: Date?
    @NSManaged public var pageNumber: Int16

}

extension NewsArticleTable {
    /// Copies a network value into a managed row while we are on its context queue.
    func copyValues(from article: Article) {
        articleID = article.id
        articleURL = article.url
        author = article.author
        heading = article.title
        descriptionData = article.description
        imageURL = article.urlToImage
        sourceName = article.source?.name
        publishedAt = article.publishedAt
        contentData = article.content
    }

    /// Creates a safe value copy. A row without a title cannot be useful in UI.
    var article: Article? {
        guard let heading else { return nil }
        return Article(
            source: Source(id: nil, name: sourceName ?? L10n.text("source.cached")),
            author: author,
            title: heading,
            description: descriptionData,
            url: articleURL ?? "",
            urlToImage: imageURL,
            publishedAt: publishedAt ?? "",
            content: contentData
        )
    }
}

extension NewsArticleTable : Identifiable {

}
