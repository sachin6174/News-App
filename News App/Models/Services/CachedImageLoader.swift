import CryptoKit
import ImageIO
import UIKit

/// Downloads article images and keeps both a fast memory copy and an offline disk
/// copy. This replaces SDWebImage with a deliberately small Foundation solution.
final class CachedImageLoader: @unchecked Sendable {
    static let shared = CachedImageLoader()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let fileManager: FileManager
    private let diskDirectory: URL
    private let maximumDiskFileCount = 300
    private let maximumImageBytes = 12_000_000

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) {
        self.session = session
        self.fileManager = fileManager

        let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskDirectory = cacheRoot.appendingPathComponent("ArticleImages", isDirectory: true)
        try? fileManager.createDirectory(
            at: diskDirectory,
            withIntermediateDirectories: true
        )
        memoryCache.countLimit = 150
    }

    /// Returns an image from memory, disk, or finally the network—in that order.
    /// Calling code owns the surrounding Swift `Task`, so a reused table cell can
    /// cancel work and avoid displaying another row's late-arriving image.
    func image(for urlString: String?) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        let key = urlString as NSString

        if let image = memoryCache.object(forKey: key) {
            return image
        }

        let fileURL = diskURL(for: urlString)
        if let data = try? Data(contentsOf: fileURL), let image = makeImage(from: data) {
            memoryCache.setObject(image, forKey: key)
            return image
        }

        do {
            let (data, response) = try await session.data(from: url)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  data.count <= maximumImageBytes,
                  let image = makeImage(from: data) else { return nil }

            memoryCache.setObject(image, forKey: key)
            try? data.write(to: fileURL, options: .atomic)
            removeOldDiskFilesIfNeeded()
            return image
        } catch {
            return nil
        }
    }

    /// SHA-256 turns any long URL into a short filesystem-safe file name.
    private func diskURL(for urlString: String) -> URL {
        let digest = SHA256.hash(data: Data(urlString.utf8))
        let fileName = digest.map { String(format: "%02x", $0) }.joined()
        return diskDirectory.appendingPathComponent(fileName)
    }

    /// Downsamples huge publisher photos to a sensible phone-list size. A 5000px
    /// photo may be only a few megabytes on disk but consume much more after decode;
    /// a 900px thumbnail keeps scrolling smooth while remaining sharp on 3× screens.
    private func makeImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 900,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else { return nil }
        return UIImage(cgImage: thumbnail)
    }

    /// Keeps the simple disk cache bounded. When it grows past 300 images, the
    /// oldest files are removed first until only 250 remain. The gap prevents us
    /// from doing cleanup after every single new image near the limit.
    private func removeOldDiskFilesIfNeeded() {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ), files.count > maximumDiskFileCount else { return }

        let oldestFirst = files.sorted { left, right in
            let leftDate = (try? left.resourceValues(forKeys: keys))?.contentModificationDate
            let rightDate = (try? right.resourceValues(forKeys: keys))?.contentModificationDate
            return (leftDate ?? .distantPast) < (rightDate ?? .distantPast)
        }
        oldestFirst.prefix(files.count - 250).forEach { try? fileManager.removeItem(at: $0) }
    }
}
