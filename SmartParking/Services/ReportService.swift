import Foundation

protocol ReportServicing: AnyObject {
    func create(
        _ report: ReportRequest,
        token: String
    ) async throws -> SpotReport

    func mine(
        token: String
    ) async throws -> [SpotReport]

    func photo(
        for report: SpotReport,
        token: String
    ) async throws -> Data
}

final class BackendReportService: ReportServicing {

    private struct ReportsResponse: Decodable {
        let reports: [SpotReport]
    }

    private let client: APIClient
    private let baseURL: URL
    private let session: URLSession

    init(
        client: APIClient = .shared,
        baseURL: URL = APIClient.configuredBaseURL,
        session: URLSession? = nil
    ) {
        self.client = client
        self.baseURL = baseURL

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil

            self.session = URLSession(
                configuration: configuration
            )
        }
    }

    // MARK: - Send report

    func create(
        _ report: ReportRequest,
        token: String
    ) async throws -> SpotReport {
        try await client.send(
            "POST",
            "/api/v1/reports",
            body: report,
            token: token
        )
    }

    // MARK: - My reports

    func mine(
        token: String
    ) async throws -> [SpotReport] {
        let response: ReportsResponse = try await client.send(
            "GET",
            "/api/v1/reports/mine",
            token: token
        )

        return response.reports
    }

    // MARK: - Authenticated report photo

    func photo(
        for report: SpotReport,
        token: String
    ) async throws -> Data {

        let expectedPath = "/api/v1/reports/\(report.id)/photo"

        guard report.photoUrl == expectedPath,
              UUID(uuidString: report.id) != nil else {
            throw APIError.server(
                status: 404,
                message: "Report photo not found."
            )
        }

        let url = baseURL.appending(path: expectedPath)

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: APIClient.readTimeout
        )

        request.httpMethod = "GET"

        request.setValue(
            "image/jpeg",
            forHTTPHeaderField: "Accept"
        )

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(
                for: request
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError
            where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.decoding
        }

        guard (200..<300).contains(http.statusCode) else {

            if http.statusCode == 401 {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .sessionExpired,
                        object: nil
                    )
                }
            }

            throw APIError.server(
                status: http.statusCode,
                message: "Could not load the report photo."
            )
        }

        guard data.starts(with: [0xFF, 0xD8, 0xFF]) else {
            throw APIError.decoding
        }

        return data
    }
}