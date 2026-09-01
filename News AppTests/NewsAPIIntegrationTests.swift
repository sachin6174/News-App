import XCTest
@testable import News_App

final class NewsAPIIntegrationTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

    /// Exercises URL construction, token auth, HTTP handling, and Codable together.
    func testRequestContainsPaginationAndTokenThenDecodesJSON() async throws {
        let session = makeStubbedSession()
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "test-token")
            let components = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "page" })?.value, "2")
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "pageSize" })?.value, "10")
            return (200, Self.goodJSON)
        }
        let service = NewsAPIService(
            session: session,
            configuration: AppConfiguration(
                newsBaseURL: URL(string: "https://example.com/news")!,
                apiToken: "test-token"
            ),
            retryPolicy: RetryPolicy(maximumRetryCount: 0, baseDelayNanoseconds: 0)
        )

        let response = try await service.fetchHeadlines(page: 2, pageSize: 10)

        XCTAssertEqual(response.totalResults, 1)
        XCTAssertEqual(response.articles.first?.title, "Integration story")
    }

    /// A temporary 500 is tried once more, then a successful response is returned.
    func testTemporaryServerFailureUsesBoundedRetry() async throws {
        let session = makeStubbedSession()
        var requestCount = 0
        URLProtocolStub.handler = { _ in
            requestCount += 1
            return requestCount == 1 ? (500, Data()) : (200, Self.goodJSON)
        }
        let service = NewsAPIService(
            session: session,
            configuration: AppConfiguration(
                newsBaseURL: URL(string: "https://example.com/news")!,
                apiToken: "test-token"
            ),
            retryPolicy: RetryPolicy(maximumRetryCount: 1, baseDelayNanoseconds: 0)
        )

        _ = try await service.fetchHeadlines(page: 1, pageSize: 20)

        XCTAssertEqual(requestCount, 2)
    }

    /// Missing credentials fail before any request can accidentally leave device.
    func testMissingTokenIsRejected() async {
        let service = NewsAPIService(
            session: makeStubbedSession(),
            configuration: AppConfiguration(
                newsBaseURL: URL(string: "https://example.com/news")!,
                apiToken: ""
            )
        )

        do {
            _ = try await service.fetchHeadlines(page: 1, pageSize: 20)
            XCTFail("A request without a token should not succeed.")
        } catch {
            XCTAssertEqual(error as? NetworkError, .missingToken)
        }
    }

    /// Cancelling the parent Swift task must stop URLSession instead of showing a
    /// late error or allowing an old response to win over a newer refresh.
    func testCancellationStopsInFlightRequest() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SlowURLProtocolStub.self]
        let service = NewsAPIService(
            session: URLSession(configuration: configuration),
            configuration: AppConfiguration(
                newsBaseURL: URL(string: "https://example.com/news")!,
                apiToken: "test-token"
            ),
            retryPolicy: RetryPolicy(maximumRetryCount: 0, baseDelayNanoseconds: 0)
        )
        let requestTask = Task {
            try await service.fetchHeadlines(page: 1, pageSize: 20)
        }

        try await Task.sleep(nanoseconds: 20_000_000)
        requestTask.cancel()

        do {
            _ = try await requestTask.value
            XCTFail("A cancelled request should not return a response.")
        } catch is CancellationError {
            // This is the exact success condition for the test.
        } catch {
            XCTFail("Expected CancellationError, received \(error)")
        }
    }

    private func makeStubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    fileprivate static let goodJSON = Data("""
    {
      "status": "ok",
      "totalResults": 1,
      "articles": [{
        "source": {"id": "fixture", "name": "Test News"},
        "author": "Reporter",
        "title": "Integration story",
        "description": "Decoded from JSON.",
        "url": "https://example.com/story",
        "urlToImage": null,
        "publishedAt": "2026-01-01T00:00:00Z",
        "content": null
      }]
    }
    """.utf8)
}

/// `URLProtocol` is an in-process pretend server used by integration tests.
private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (status: Int, data: Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let result = try XCTUnwrap(Self.handler)(request)
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: result.status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: result.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// A deliberately slow fake proves that cancellation happens before completion.
private final class SlowURLProtocolStub: URLProtocol {
    private var pendingWork: DispatchWorkItem?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let work = DispatchWorkItem { [weak self] in
            guard let self, let url = self.request.url else { return }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: NewsAPIIntegrationTests.goodJSON)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        pendingWork = work
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    override func stopLoading() {
        pendingWork?.cancel()
        pendingWork = nil
    }
}
