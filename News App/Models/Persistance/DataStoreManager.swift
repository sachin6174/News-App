//
//  DataStoreManager.swift
//  News App
//
//  Created by sachin kumar on 14/09/25.
//

import Foundation
import CoreData

/// A thread-safe Core Data manager for database operations.
final class DataStoreManager {
    
    // MARK: - Singleton
    static let shared = DataStoreManager()
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleContextSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    // MARK: - Persistent Container
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "News_App")
        
        guard let baseDirectory = try? PathUtility.appDatabaseDirectory() else {
            Logger.error("Unable to resolve base database directory.")
            fatalError("Could not resolve database directory.")
        }
        
        let dbDirectory = baseDirectory.appendingPathComponent("Storage")
        createDirectoryIfNeeded(at: dbDirectory)
        
        let storeURL = dbDirectory.appendingPathComponent("News_App.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
        container.persistentStoreDescriptions = [description]
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        container.loadPersistentStores { _, error in
            if let error = error {
                Logger.error("Failed to load Core Data store: \(error)")
            }
        }
        
        applyFilePermissions(in: dbDirectory)
        return container
    }()
    
    var mainContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Save Context
    func saveContext() {
        guard mainContext.hasChanges else { return }
        do {
            try mainContext.save()
        } catch {
            Logger.error("Save failed: \(error)")
        }
    }
    
    // MARK: - Background Tasks
    func performBackgroundTask(
        _ block: @escaping (NSManagedObjectContext) -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        persistentContainer.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            context.performAndWait {
                block(context)
                if context.hasChanges {
                    do {
                        try context.save()
                        completion?(true)
                    } catch {
                        Logger.error("Background save failed: \(error)")
                        completion?(false)
                    }
                } else {
                    completion?(true)
                }
            }
        }
    }
    
    // MARK: - Notification Handling
    @objc private func handleContextSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext,
              context != mainContext else { return }
        mainContext.perform {
            self.mainContext.mergeChanges(fromContextDidSave: notification)
        }
    }
    
    // MARK: - CRUD Operations
    func create<T: NSManagedObject>(_: T.Type, in context: NSManagedObjectContext) -> T {
        let entityName = String(describing: T.self)
        guard let entity = NSEntityDescription.insertNewObject(
            forEntityName: entityName,
            into: context
        ) as? T else {
            fatalError("Entity creation failed for \(entityName)")
        }
        return entity
    }
    
    func fetch<T: NSManagedObject>(
        _: T.Type,
        predicate: NSPredicate? = nil,
        sort: [NSSortDescriptor]? = nil,
        limit: Int? = nil,
        offset: Int? = nil,
        in context: NSManagedObjectContext
    ) -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: T.self))
        request.predicate = predicate
        request.sortDescriptors = sort
        if let limit = limit { request.fetchLimit = limit }
        if let offset = offset { request.fetchOffset = offset }
        
        do {
            return try context.fetch(request)
        } catch {
            Logger.error("Fetch failed: \(error)")
            return []
        }
    }
    
    func count<T: NSManagedObject>(
        _: T.Type,
        predicate: NSPredicate? = nil,
        in context: NSManagedObjectContext
    ) -> Int {
        let request = NSFetchRequest<T>(entityName: String(describing: T.self))
        request.predicate = predicate
        do {
            return try context.count(for: request)
        } catch {
            Logger.error("Count failed: \(error)")
            return 0
        }
    }
    
    func update<T: NSManagedObject>(_ entity: T, updates: (T) -> Void) {
        updates(entity)
    }
    
    func delete<T: NSManagedObject>(_ entity: T, in context: NSManagedObjectContext) {
        context.delete(entity)
    }
    
    func deleteAll<T: NSManagedObject>(
        _: T.Type,
        completion: ((Bool) -> Void)? = nil
    ) {
        performBackgroundTask { context in
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: String(describing: T.self)
            )
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            do {
                try context.execute(deleteRequest)
            } catch {
                Logger.error("Failed to batch delete: \(error)")
            }
        } completion: { success in
            completion?(success)
        }
    }

    // MARK: - Bookmark Operations
    func saveBookmark(for article: Article) {
        let context = mainContext
        let bookmark = create(NewsArticleTable.self, in: context)

        bookmark.uuid = UUID()
        bookmark.heading = article.title
        bookmark.descriptionData = article.description
        bookmark.imageURL = article.urlToImage
        bookmark.dateInfo = DateFormatter().date(from: article.publishedAt) ?? Date()
        bookmark.isABookMark = true

        saveContext()
    }

    func removeBookmark(for article: Article) {
        let context = mainContext
        let predicate = NSPredicate(format: "heading == %@", article.title)
        let bookmarks = fetch(NewsArticleTable.self, predicate: predicate, in: context)

        for bookmark in bookmarks {
            delete(bookmark, in: context)
        }

        saveContext()
    }

    func fetchBookmarkedArticles() -> [Article] {
        let context = mainContext
        let predicate = NSPredicate(format: "isABookMark == %@", NSNumber(value: true))
        let bookmarks = fetch(NewsArticleTable.self, predicate: predicate, in: context)

        return bookmarks.compactMap { bookmark in
            guard let title = bookmark.heading else { return nil }

            let source = Source(id: nil, name: "Bookmarked")
            return Article(
                source: source,
                author: nil,
                title: title,
                description: bookmark.descriptionData,
                url: "",
                urlToImage: bookmark.imageURL,
                publishedAt: DateFormatter().string(from: bookmark.dateInfo ?? Date()),
                content: nil
            )
        }
    }
    
    // MARK: - File Utilities
    private func createDirectoryIfNeeded(at url: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                Logger.error("Failed to create directory: \(error)")
            }
        }
    }
    
    private func applyFilePermissions(in directory: URL) {
        let fm = FileManager.default
        do {
            let files = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files {
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
            }
        } catch {
            Logger.error("Failed to set permissions: \(error)")
        }
    }
}

// MARK: - Helper Utilities
enum Logger {
    static func error(_ message: String) {
        NSLog("[CoreDataError] \(message)")
    }
}

enum PathUtility {
    static func appDatabaseDirectory() throws -> URL {
        // Customize base directory resolution as needed
        let fm = FileManager.default
        let supportDir = try fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
        return supportDir.appendingPathComponent("AppData")
    }
}
