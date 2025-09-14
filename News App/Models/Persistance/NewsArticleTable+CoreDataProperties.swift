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

}

extension NewsArticleTable : Identifiable {

}
