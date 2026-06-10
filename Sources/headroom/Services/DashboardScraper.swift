import Foundation

/// Scrapes the OpenCode Go workspace dashboard for quota usage data.
///
/// The dashboard is a SolidJS application with server-side rendering (SSR).
/// Quota data is embedded in the HTML as hydration output in the form:
/// ```
/// rollingUsage:$R[N]={usagePercent:42,resetInSec:3600}
/// ```
/// (and similarly for `weeklyUsage`, `monthlyUsage`).
///
/// This approach is used by all existing third-party tools:
/// - slkiser/opencode-quota (1k+ stars)
/// - pi-go-bars
/// - opencode-go-usage
public struct DashboardScraper: Sendable {

    private static let dashboardURLTemplate = "https://opencode.ai/workspace/%@/go"
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Gecko/20100101 Firefox/148.0"
    private static let requestTimeout: TimeInterval = 10

    private let session: URLSession
    private let decoder: ScrapedDataDecoder

    public init(session: URLSession = .shared, decoder: ScrapedDataDecoder = ScrapedDataDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    /// Fetch quota usage by scraping the OpenCode Go dashboard.
    /// - Parameters:
    ///   - workspaceId: The workspace ID from the dashboard URL.
    ///   - authCookie: The `auth` cookie value for `opencode.ai`.
    /// - Returns: Parsed `QuotaUsage` data.
    /// - Throws: `QuotaError` on network, auth, or parsing failures.
    public func fetch(workspaceId: String, authCookie: String) async throws -> QuotaUsage {
        let urlString = String(format: Self.dashboardURLTemplate, workspaceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? workspaceId)

        guard let url = URL(string: urlString) else {
            throw QuotaError.parse("Invalid dashboard URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("auth=\(authCookie)", forHTTPHeaderField: "Cookie")
        request.timeoutInterval = Self.requestTimeout

        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw QuotaError.network("Request timed out after \(Self.requestTimeout)s")
        } catch {
            throw QuotaError.network("Network error: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.network("Invalid response type")
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw QuotaError.parse("Dashboard response is not valid UTF-8 text")
        }

        switch httpResponse.statusCode {
        case 200:
            break // OK, continue parsing
        case 302, 303:
            throw QuotaError.auth("Dashboard redirected — auth cookie may be expired")
        case 401, 403:
            throw QuotaError.auth("Dashboard returned \(httpResponse.statusCode) — auth cookie may be invalid or expired")
        case 404:
            throw QuotaError.parse("Dashboard not found — check workspace ID")
        case 429:
            throw QuotaError.network("Rate limited by OpenCode dashboard")
        default:
            throw QuotaError.network("Dashboard returned HTTP \(httpResponse.statusCode)")
        }

        // Check for login page redirect (no workspace content)
        if html.contains("sign-in") || html.contains("login") || html.contains("Sign in") {
            throw QuotaError.auth("Dashboard is showing a login page — auth cookie may be expired")
        }

        return try decoder.decode(html: html)
    }
}

// MARK: - HTML Parsing

/// Decodes quota data from the SolidJS SSR hydration output in the dashboard HTML.
public struct ScrapedDataDecoder: Sendable {

    // Regex patterns matching SolidJS SSR hydration output.
    // The patterns match objects like:
    //   rollingUsage:$R[N]={usagePercent:42,resetInSec:3600}
    // Field order varies, so we try both orderings: usagePercent first, resetInSec first.

    private static let numberPattern = "(-?\\d+(?:\\.\\d+)?)"

    // Rolling usage — usagePercent first
    private static let rollingPctFirst = try! NSRegularExpression(
        pattern: "rollingUsage:\\$R\\[\\d+\\]=\\{[^}]*usagePercent:\(numberPattern)[^}]*resetInSec:\(numberPattern)[^}]*\\}"
    )
    // Rolling usage — resetInSec first
    private static let rollingResetFirst = try! NSRegularExpression(
        pattern: "rollingUsage:\\$R\\[\\d+\\]=\\{[^}]*resetInSec:\(numberPattern)[^}]*usagePercent:\(numberPattern)[^}]*\\}"
    )

    // Weekly usage — usagePercent first
    private static let weeklyPctFirst = try! NSRegularExpression(
        pattern: "weeklyUsage:\\$R\\[\\d+\\]=\\{[^}]*usagePercent:\(numberPattern)[^}]*resetInSec:\(numberPattern)[^}]*\\}"
    )
    // Weekly usage — resetInSec first
    private static let weeklyResetFirst = try! NSRegularExpression(
        pattern: "weeklyUsage:\\$R\\[\\d+\\]=\\{[^}]*resetInSec:\(numberPattern)[^}]*usagePercent:\(numberPattern)[^}]*\\}"
    )

    // Monthly usage — usagePercent first
    private static let monthlyPctFirst = try! NSRegularExpression(
        pattern: "monthlyUsage:\\$R\\[\\d+\\]=\\{[^}]*usagePercent:\(numberPattern)[^}]*resetInSec:\(numberPattern)[^}]*\\}"
    )
    // Monthly usage — resetInSec first
    private static let monthlyResetFirst = try! NSRegularExpression(
        pattern: "monthlyUsage:\\$R\\[\\d+\\]=\\{[^}]*resetInSec:\(numberPattern)[^}]*usagePercent:\(numberPattern)[^}]*\\}"
    )

    public init() {}

    /// Parse quota usage from the dashboard HTML.
    /// - Parameter html: The full HTML of the dashboard page.
    /// - Returns: Parsed `QuotaUsage`.
    /// - Throws: `QuotaError.parse` if no quota windows can be extracted.
    public func decode(html: String) throws -> QuotaUsage {
        let rolling = decodeWindow(html: html,
                                   pctFirstPattern: Self.rollingPctFirst,
                                   resetFirstPattern: Self.rollingResetFirst)
        let weekly = decodeWindow(html: html,
                                  pctFirstPattern: Self.weeklyPctFirst,
                                  resetFirstPattern: Self.weeklyResetFirst)
        let monthly = decodeWindow(html: html,
                                   pctFirstPattern: Self.monthlyPctFirst,
                                   resetFirstPattern: Self.monthlyResetFirst)

        if rolling == nil && weekly == nil && monthly == nil {
            throw QuotaError.parse(
                "Could not find any quota window data in the dashboard HTML. " +
                "The OpenCode Go dashboard format may have changed. " +
                "Expected patterns: rollingUsage, weeklyUsage, monthlyUsage in SolidJS SSR output."
            )
        }

        return QuotaUsage(
            rolling: rolling,
            weekly: weekly,
            monthly: monthly,
            lastUpdated: Date()
        )
    }

    /// Extract a single quota window from the HTML using two regex patterns (field order variants).
    private func decodeWindow(html: String, pctFirstPattern: NSRegularExpression, resetFirstPattern: NSRegularExpression) -> QuotaWindow? {
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)

        // Try usagePercent first
        if let match = pctFirstPattern.firstMatch(in: html, range: nsRange),
           let pctRange = Range(match.range(at: 1), in: html),
           let resetRange = Range(match.range(at: 2), in: html),
           let usagePercent = Double(html[pctRange]),
           let resetInSec = Double(html[resetRange]) {
            return QuotaWindow(usagePercent: usagePercent, resetInSeconds: resetInSec)
        }

        // Try resetInSec first
        if let match = resetFirstPattern.firstMatch(in: html, range: nsRange),
           let resetRange = Range(match.range(at: 1), in: html),
           let pctRange = Range(match.range(at: 2), in: html),
           let resetInSec = Double(html[resetRange]),
           let usagePercent = Double(html[pctRange]) {
            return QuotaWindow(usagePercent: usagePercent, resetInSeconds: resetInSec)
        }

        return nil
    }
}
