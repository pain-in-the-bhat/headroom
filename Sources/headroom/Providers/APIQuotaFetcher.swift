import Foundation

/// Fetches OpenCode Go quota via the official API endpoint.
///
/// ⚠️ This endpoint is NOT yet available in production.
/// PR #16513 (https://github.com/anomalyco/opencode/pull/16513) proposes
/// adding `GET /zen/go/v1/usage` but has not been merged.
///
/// Once the endpoint ships, this fetcher will be the primary data source.
/// Expected response format:
/// ```json
/// {
///   "rolling": { "usagePercent": 42, "resetInSeconds": 3600 },
///   "weekly": { "usagePercent": 30, "resetInSeconds": 604800 },
///   "monthly": { "usagePercent": 12, "resetInSeconds": 2592000 }
/// }
/// ```
///
/// For now, this struct always throws `QuotaError` indicating the API
/// is not available. It serves as a placeholder for future implementation.
public struct APIQuotaFetcher: QuotaFetcher, Sendable {

    public enum Endpoint: String {
        case usage = "https://opencode.ai/zen/go/v1/usage"
    }

    public let apiKey: String
    public let session: URLSession

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func fetch() async throws -> QuotaUsage {
        // The API endpoint is not yet available.
        // This implementation will be completed once PR #16513 ships.
        //
        // Expected implementation:
        //
        // var request = URLRequest(url: URL(string: Endpoint.usage.rawValue)!)
        // request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        // request.setValue("application/json", forHTTPHeaderField: "Accept")
        //
        // let (data, response) = try await session.data(for: request)
        //
        // guard let httpResponse = response as? HTTPURLResponse else {
        //     throw QuotaError.network("Invalid response")
        // }
        //
        // switch httpResponse.statusCode {
        // case 200:
        //     let apiResponse = try decoder.decode(APIResponse.self, from: data)
        //     return apiResponse.toQuotaUsage()
        // case 401:
        //     throw QuotaError.auth("Invalid API key")
        // case 429:
        //     throw QuotaError.network("Rate limited")
        // default:
        //     throw QuotaError.network("HTTP \(httpResponse.statusCode)")
        // }

        throw QuotaError(
            message: "OpenCode Go usage API endpoint is not yet available. " +
                     "Track PR #16513 at github.com/anomalyco/opencode. " +
                     "Use ScrapingQuotaFetcher instead.",
            isAuthError: false,
            isTransient: false
        )
    }
}

// MARK: - Expected API Response Types
// These will be used once the endpoint ships.

// struct APIResponse: Decodable {
//     let rolling: WindowDTO?
//     let weekly: WindowDTO?
//     let monthly: WindowDTO?
//
//     struct WindowDTO: Decodable {
//         let usagePercent: Double
//         let resetInSeconds: TimeInterval
//     }
//
//     func toQuotaUsage() -> QuotaUsage {
//         QuotaUsage(
//             rolling: rolling.map { QuotaWindow(usagePercent: $0.usagePercent, resetInSeconds: $0.resetInSeconds) },
//             weekly: weekly.map { QuotaWindow(usagePercent: $0.usagePercent, resetInSeconds: $0.resetInSeconds) },
//             monthly: monthly.map { QuotaWindow(usagePercent: $0.usagePercent, resetInSeconds: $0.resetInSeconds) },
//             lastUpdated: Date()
//         )
//     }
// }
