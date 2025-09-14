//
//  SDWebImageHandler.swift
//  News App
//
//  Created by sachin kumar on 15/09/25.
//
import SDWebImage

class SDWebImageHandler {
    
    static let shared = SDWebImageHandler()
    
    // In-memory cache
    private var cache: [UUID: UIImage] = [:]
    
    private init() {}
    
    // MARK: - Save (Download & Cache Image)
    func saveImage(uuid: UUID, urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        // Download using URLSession
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            
            // Save in cache
            self?.cache[uuid] = image
            completion(image)
        }.resume()
    }
    
    // MARK: - Read (Get Image by UUID)
    func getImage(uuid: UUID) -> UIImage? {
        return cache[uuid]
    }
    
    // MARK: - Update (Replace Cached Image)
    func updateImage(uuid: UUID, newURL: String, completion: @escaping (UIImage?) -> Void) {
        deleteImage(uuid: uuid) // remove old
        
        saveImage(uuid: uuid, urlString: newURL) { image in
            completion(image)
        }
    }
    
    // MARK: - Delete
    func deleteImage(uuid: UUID) {
        cache.removeValue(forKey: uuid)
    }
}
