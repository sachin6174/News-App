import CoreData
import Foundation

/// A small Core Data store that owns all database threading.
///
/// Core Data objects belong to the queue that created them, rather like a toy that
/// must stay in its own room. Every method below opens a background context, does
/// all work inside that context, and returns plain `Article` values that are safe
/// to carry anywhere in the app.
final class DataStoreManager: @unchecked Sendable {
    static let shared = DataStoreManager()

    private let container: NSPersistentContainer

    /// `inMemory` is true in tests so the database disappears after each test.
    /// Production uses an automatically migrated SQLite store on disk.
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "News_App")

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        } else {
            container.persistentStoreDescriptions.forEach { description in
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
            }
        }

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Core Data could not open its store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Saves a page of ordinary headlines for offline use.
    ///
    /// Page one represents a brand-new feed, so its arrival removes the older
    /// non-bookmark snapshot. Later pages are appended. Bookmark rows are never
    /// touched, which means refreshing news cannot erase a user's saved story.
    func storeCached(_ articles: [Article], page: Int) async throws {
        try await performBackground { context in
            if page == 1 {
                let request = NewsArticleTable.fetchRequest()
                request.predicate = NSPredicate(format: "isABookMark == NO")
                let oldRows = try context.fetch(request)
                oldRows.forEach(context.delete)
            } else {
                let request = NewsArticleTable.fetchRequest()
                request.predicate = NSPredicate(
                    format: "isABookMark == NO AND pageNumber == %d",
                    page
                )
                let oldRows = try context.fetch(request)
                oldRows.forEach(context.delete)
            }

            for article in articles {
                let row = NewsArticleTable(context: context)
                row.copyValues(from: article)
                row.uuid = UUID()
                row.isABookMark = false
                row.pageNumber = Int16(page)
                row.cachedAt = Date()
            }
        }
    }

    /// Returns cached stories in API-page order, then newest-first within a page.
    func fetchCachedArticles() async -> [Article] {
        await fetchRows(isBookmark: false)
    }

    /// Returns every bookmark as a plain value.
    func fetchBookmarkedArticles() async -> [Article] {
        await fetchRows(isBookmark: true)
    }

    /// Makes the database match one requested bookmark state.
    ///
    /// We first remove any existing row with this stable article ID. If the final
    /// state should be saved, we insert exactly one fresh row. This remove-then-add
    /// approach is intentionally simple and prevents duplicate bookmark entries.
    func setBookmarked(_ isBookmarked: Bool, article: Article) async {
        do {
            try await performBackground { context in
                let request = NewsArticleTable.fetchRequest()
                request.predicate = NSPredicate(
                    format: "isABookMark == YES AND (articleID == %@ OR (articleID == nil AND heading == %@))",
                    article.id,
                    article.title
                )
                let oldRows = try context.fetch(request)
                oldRows.forEach(context.delete)

                if isBookmarked {
                    let row = NewsArticleTable(context: context)
                    row.copyValues(from: article)
                    row.uuid = UUID()
                    row.isABookMark = true
                    row.pageNumber = 0
                    row.cachedAt = Date()
                }
            }
        } catch {
            Logger.error("Could not update bookmark: \(error)")
        }
    }

    /// Runs one throwing database closure and waits for its context to save.
    private func performBackground(
        _ work: @escaping (NSManagedObjectContext) throws -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                do {
                    try work(context)
                    if context.hasChanges {
                        try context.save()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Fetches rows on a safe queue and converts them before leaving that queue.
    private func fetchRows(isBookmark: Bool) async -> [Article] {
        await withCheckedContinuation { continuation in
            container.performBackgroundTask { context in
                let request = NewsArticleTable.fetchRequest()
                request.predicate = NSPredicate(
                    format: "isABookMark == %@",
                    NSNumber(value: isBookmark)
                )
                request.sortDescriptors = [
                    NSSortDescriptor(key: "pageNumber", ascending: true),
                    NSSortDescriptor(key: "publishedAt", ascending: false)
                ]

                do {
                    let articles = try context.fetch(request).compactMap(\.article)
                    continuation.resume(returning: articles)
                } catch {
                    Logger.error("Could not read cached articles: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
}

/// Central logging keeps Core Data errors recognisable in the Xcode console.
enum Logger {
    static func error(_ message: String) {
        NSLog("[NewsApp] %@", message)
    }
}
