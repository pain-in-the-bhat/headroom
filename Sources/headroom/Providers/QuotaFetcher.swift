import Foundation

/// Credentials required to fetch OpenCode Go quota.
public struct OpenCodeCredentials: Codable, Equatable, Sendable {
    public let workspaceId: String
    public let authCookie: String
    public let apiKey: String?

    public init(workspaceId: String, authCookie: String, apiKey: String? = nil) {
        self.workspaceId = workspaceId
        self.authCookie = authCookie
        self.apiKey = apiKey
    }
}

/// Strategy for fetching quota data.
public enum FetchStrategy: String, CaseIterable, Codable, Sendable {
    /// Try API first, fall back to scraping
    case auto
    /// Only use dashboard scraping
    case scraping
    /// Only use the API endpoint (future)
    case api
    /// Use mock data (development/testing)
    case mock
}

/// Protocol abstracting the data source for quota information.
///
/// This allows swapping between:
/// - Dashboard scraping (current approach, proven in production)
/// - API endpoint (future, once PR #16513 is merged)
/// - Mock data (development/testing)
public protocol QuotaFetcher: Sendable {
    /// Fetch the latest quota usage from the data source.
    /// - Returns: `QuotaUsage` if successful.
    /// - Throws: `QuotaError` on failure.
    func fetch() async throws -> QuotaUsage
}
