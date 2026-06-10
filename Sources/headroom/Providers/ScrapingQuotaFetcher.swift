import Foundation

/// Fetches OpenCode Go quota by scraping the workspace dashboard page.
///
/// This is the current approach used by all third-party tools (opencode-quota,
/// pi-go-bars, opencode-go-usage) because OpenCode does not yet have a public
/// API for Go plan quota data (see PR #16513).
///
/// The scraper fetches the HTML dashboard and parses SolidJS SSR hydration
/// output embedded in the page.
public struct ScrapingQuotaFetcher: QuotaFetcher, Sendable {

    public let credentials: OpenCodeCredentials
    public let scraper: DashboardScraper

    public init(credentials: OpenCodeCredentials, scraper: DashboardScraper = DashboardScraper()) {
        self.credentials = credentials
        self.scraper = scraper
    }

    public func fetch() async throws -> QuotaUsage {
        return try await scraper.fetch(
            workspaceId: credentials.workspaceId,
            authCookie: credentials.authCookie
        )
    }
}
