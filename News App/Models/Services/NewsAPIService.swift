import Foundation

/// Clear errors let the UI explain what went wrong instead of showing the very
/// unhelpful sentence "The operation could not be completed."
enum NetworkError: LocalizedError, Equatable {
    case missingToken
    case invalidResponse
    case httpStatus(Int)
    case emptyData
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return L10n.text("error.missing.token")
        case .invalidResponse:
            return L10n.text("error.invalid.response")
        case .httpStatus(let code):
            return String(format: L10n.text("error.http.status"), code)
        case .emptyData:
            return L10n.text("error.empty.data")
        case .decodingFailed:
            return L10n.text("error.decoding")
        }
    }
}

/// These numbers live in their own value so tests can turn delays off.
struct RetryPolicy: Sendable {
    let maximumRetryCount: Int
    let baseDelayNanoseconds: UInt64

    static let production = RetryPolicy(
        maximumRetryCount: 2,
        baseDelayNanoseconds: 500_000_000
    )
}

/// A small REST client built only from Foundation and `URLSession`.
final class NewsAPIService {
    private let session: URLSession
    private let configuration: AppConfiguration
    private let retryPolicy: RetryPolicy
    private let decoder: JSONDecoder

    init(
        session: URLSession = .shared,
        configuration: AppConfiguration = .live(),
        retryPolicy: RetryPolicy = .production,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        self.configuration = configuration
        self.retryPolicy = retryPolicy
        self.decoder = decoder
    }

    /// Downloads and decodes one page of headlines.
    ///
    /// The API key goes in a request header, not the URL. URLs are commonly kept
    /// in browser history and server logs, so headers are the safer home for a
    /// token. `URLSession.data(for:)` automatically cooperates with Swift Task
    /// cancellation: cancelling the parent task also stops the network request.
    func fetchHeadlines(page: Int, pageSize: Int) async throws -> NewsResponse {
        guard !configuration.apiToken.isEmpty,
              configuration.apiToken != "$(NEWS_API_KEY)" else {
            throw NetworkError.missingToken
        }

        var components = URLComponents(
            url: configuration.newsBaseURL,
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "country", value: "us"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(configuration.apiToken, forHTTPHeaderField: "X-Api-Key")

        return try await perform(request, responseType: NewsResponse.self)
    }

    /// Performs a request and retries only failures that may succeed later.
    ///
    /// Backoff waits 0.5 seconds, then 1 second. We deliberately cap retries so a
    /// broken server never traps the user in an endless spinner. A cancellation
    /// error is immediately rethrown because "stop" must really mean stop.
    private func perform<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        var retryNumber = 0

        while true {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw NetworkError.httpStatus(httpResponse.statusCode)
                }

                guard !data.isEmpty else {
                    throw NetworkError.emptyData
                }

                do {
                    return try decoder.decode(responseType, from: data)
                } catch {
                    throw NetworkError.decodingFailed
                }
            } catch {
                // URLSession may report cancellation as `URLError.cancelled` rather
                // than `CancellationError`, so the Task flag is the source of truth.
                if Task.isCancelled { throw CancellationError() }
                guard retryNumber < retryPolicy.maximumRetryCount,
                      shouldRetry(error) else {
                    throw error
                }

                let multiplier = UInt64(1 << retryNumber)
                let delay = retryPolicy.baseDelayNanoseconds * multiplier
                retryNumber += 1
                try await Task.sleep(nanoseconds: delay)
            }
        }
    }

    /// Returns true only for temporary server, rate-limit, or connection errors.
    private func shouldRetry(_ error: Error) -> Bool {
        if case NetworkError.httpStatus(let code) = error {
            return code == 408 || code == 429 || (500...599).contains(code)
        }

        if let urlError = error as? URLError {
            return [
                .timedOut,
                .networkConnectionLost,
                .notConnectedToInternet,
                .cannotConnectToHost
            ].contains(urlError.code)
        }

        return false
    }
}
