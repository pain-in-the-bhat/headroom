import Foundation

/// Mock fetcher that generates realistic-looking quota data.
///
/// Use this for development and testing without a real OpenCode subscription.
/// The values fluctuate randomly within realistic ranges so the UI stays testable.
public actor MockQuotaFetcher: QuotaFetcher {

    private var lastFetch = Date()
    private var usageOffset: Double = 0

    /// Seed for reproducible mock data
    public let seed: Int

    public init(seed: Int = 42) {
        self.seed = seed
    }

    public func fetch() async throws -> QuotaUsage {
        // Simulate network latency
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Advance the offset slightly each call so values change
        usageOffset += Double(seed) * 0.01
        let base = sin(usageOffset) * 15 // slight oscillation for realism

        let now = Date()

        let rolling = QuotaWindow(
            usagePercent: 38 + base + Double.random(in: -5...5),
            resetInSeconds: 7_920 + TimeInterval.random(in: -300...300)  // ~2.2 hours
        )

        let weekly = QuotaWindow(
            usagePercent: 59 + base + Double.random(in: -8...8),
            resetInSeconds: 280_800 + TimeInterval.random(in: -3600...3600)  // ~3.25 days
        )

        let monthly = QuotaWindow(
            usagePercent: 82 + Double.random(in: -10...10),
            resetInSeconds: 1_080_000 + TimeInterval.random(in: -86400...86400)  // ~12.5 days
        )

        return QuotaUsage(
            rolling: rolling,
            weekly: weekly,
            monthly: monthly,
            lastUpdated: now
        )
    }
}
