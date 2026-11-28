import Foundation

protocol WeekForecastServicing: AnyObject, Sendable {
    func week(level: String) async throws -> WeekForecastResponse
}

final class BackendWeekForecastService: WeekForecastServicing, @unchecked Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func week(level: String) async throws -> WeekForecastResponse {
        try await client.send(
            "GET",
            "/api/v1/predictions/week",
            query: [URLQueryItem(name: "level", value: level)]
        )
    }
}
