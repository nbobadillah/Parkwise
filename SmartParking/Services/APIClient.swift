import Foundation

extension Notification.Name {
    static let sessionExpired = Notification.Name("sessionExpired")
}

enum APIError: LocalizedError {
    case network
    case server(status: Int, message: String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .network: return "Could not reach the Parkwise server. Check your connection."
        case .server(_, let message): return message
        case .decoding: return "The server sent an unexpected response."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private struct ErrorBody: Decodable {
        let error: String
    }

    private let baseURL: URL
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder

    init(baseURL: URL = APIClient.configuredBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(APIClient.decodeDate)
    }

    static var configuredBaseURL: URL {
        let value = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String
        return value.flatMap(URL.init(string:)) ?? URL(string: "http://localhost:3000")!
    }

    static func iso8601String(from date: Date) -> String {
        date.formatted(.iso8601)
    }

    func send<Response: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        token: String? = nil
    ) async throws -> Response {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else { throw APIError.network }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.decoding }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401, token != nil {
                await MainActor.run {
                    NotificationCenter.default.post(name: .sessionExpired, object: nil)
                }
            }
            let message = (try? decoder.decode(ErrorBody.self, from: data))?.error ?? "Request failed."
            throw APIError.server(status: http.statusCode, message: message)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    @Sendable private static func decodeDate(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
            return date
        }
        if let date = try? Date.ISO8601FormatStyle().parse(value) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO 8601 date: \(value)")
    }
}
