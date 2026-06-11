import Foundation

enum OdinHTTPError: Error {
    case nonHTTPResponse
    case badStatusCode(Int)
}

protocol OdinHTTPClient {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, HTTPURLResponse)
}

final class URLSessionOdinHTTPClient: OdinHTTPClient {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    convenience init(
        requestTimeout: TimeInterval,
        resourceTimeout: TimeInterval
    ) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout

        self.init(session: URLSession(configuration: configuration))
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OdinHTTPError.nonHTTPResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw OdinHTTPError.badStatusCode(httpResponse.statusCode)
        }

        return (data, httpResponse)
    }

    func bytes(
        for request: URLRequest
    ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OdinHTTPError.nonHTTPResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw OdinHTTPError.badStatusCode(httpResponse.statusCode)
        }

        return (bytes, httpResponse)
    }
}
