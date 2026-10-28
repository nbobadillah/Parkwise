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

@MainActor
final class ServerStatus: ObservableObject {
    static let shared = ServerStatus()

    @Published private(set) var isWaking = false

    private var waitingRequests = 0

    func beginWaiting() {
        waitingRequests += 1
        isWaking = true
    }

    func endWaiting() {
        waitingRequests = max(0, waitingRequests - 1)
        isWaking = waitingRequests > 0
    }
}

final class APIClient {
    static let shared = APIClient()
    static let readTimeout: TimeInterval = 20
    static let writeTimeout: TimeInterval = 60
    static let readAttempts = 3

    private static let retryableURLErrors: Set<URLError.Code> = [.timedOut, .cannotConnectToHost, .networkConnectionLost]
    private static let retryableStatuses: Set<Int> = [502, 503, 504]

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
        request.timeoutInterval = method == "GET" ? Self.readTimeout : Self.writeTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await perform(request, attempts: method == "GET" ? Self.readAttempts : 1)

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

    private func perform(_ request: URLRequest, attempts: Int) async throws -> (Data, URLResponse) {
        var isWaiting = false
        defer {
            if isWaiting {
                Task { @MainActor in ServerStatus.shared.endWaiting() }
            }
        }
        for attempt in 1...attempts {
            let isLast = attempt == attempts
            do {
                let (data, response) = try await session.data(for: request)
                if !isLast, let status = (response as? HTTPURLResponse)?.statusCode, Self.retryableStatuses.contains(status) {
                    try await waitBeforeRetry(&isWaiting)
                    continue
                }
                return (data, response)
            } catch let error as URLError where !isLast && Self.retryableURLErrors.contains(error.code) {
                try await waitBeforeRetry(&isWaiting)
            } catch {
                throw APIError.network
            }
        }
        throw APIError.network
    }

    private func waitBeforeRetry(_ isWaiting: inout Bool) async throws {
        if !isWaiting {
            isWaiting = true
            await MainActor.run { ServerStatus.shared.beginWaiting() }
        }
        do {
            try await Task.sleep(for: .seconds(2))
        } catch {
            throw APIError.network
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
