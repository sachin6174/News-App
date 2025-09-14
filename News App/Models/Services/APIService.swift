//
//  APIService.swift
//  News App
//
//  Created by sachin kumar on 14/09/25.
//
import Foundation

final class APIService {
    static let shared = APIService()
    private init() {}
    
    /// Generic API Caller
    func request<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem] = [],
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        var components = URLComponents(string: endpoint)
        components?.queryItems = queryItems + [URLQueryItem(name: "apiKey", value: AppConstants.apiKey)]
        
        guard let url = components?.url else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "No Data", code: -1)))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}

