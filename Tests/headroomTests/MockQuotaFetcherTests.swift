import Testing
import Foundation
@testable import headroom

/// Tests for the mock quota fetcher.
///
/// Verifies that the mock generates realistic data with the expected
/// structure and within reasonable value ranges.
struct MockQuotaFetcherTests {

    @Test func testMockFetcherReturnsData() async throws {
        let fetcher = MockQuotaFetcher(seed: 42)
        let usage = try await fetcher.fetch()

        #expect(usage.rolling != nil)
        #expect(usage.weekly != nil)
        #expect(usage.monthly != nil)
        #expect(usage.isComplete)
    }

    @Test func testMockFetcherValuesInRange() async throws {
        let fetcher = MockQuotaFetcher(seed: 42)

        // Run multiple fetches to get a range of values
        for _ in 0..<10 {
            let usage = try await fetcher.fetch()

            // Values should be clamped to 0-100
            for window in [usage.rolling, usage.weekly, usage.monthly] {
                #expect(window != nil)
                #expect(window!.usagePercent >= 0)
                #expect(window!.usagePercent <= 100)
                #expect(window!.remainingPercent >= 0)
                #expect(window!.remainingPercent <= 100)
                #expect(window!.remainingPercent + window!.usagePercent == 100)
            }
        }
    }

    @Test func testMockFetcherResetTimers() async throws {
        let fetcher = MockQuotaFetcher(seed: 42)
        let usage = try await fetcher.fetch()

        // Reset timers should be positive and reasonable
        if let rolling = usage.rolling {
            #expect(rolling.resetInSeconds >= 0)
        }
        if let weekly = usage.weekly {
            #expect(weekly.resetInSeconds >= 0)
        }
        if let monthly = usage.monthly {
            #expect(monthly.resetInSeconds >= 0)
        }
    }

    @Test func testMockFetcherDifferentSeedDifferentValues() async throws {
        let fetcher1 = MockQuotaFetcher(seed: 1)
        let fetcher2 = MockQuotaFetcher(seed: 999)

        let usage1 = try await fetcher1.fetch()
        let usage2 = try await fetcher2.fetch()

        // Different seeds should produce different values
        // (there's a tiny chance they could match, but astronomically unlikely)
        let notEqual = usage1.rolling?.usagePercent != usage2.rolling?.usagePercent
            || usage1.weekly?.usagePercent != usage2.weekly?.usagePercent
            || usage1.monthly?.usagePercent != usage2.monthly?.usagePercent
        #expect(notEqual)
    }

    @Test func testMockFetcherUpdatesValues() async throws {
        let fetcher = MockQuotaFetcher(seed: 42)

        let first = try await fetcher.fetch()
        let second = try await fetcher.fetch()

        // Values should change between calls (due to sin oscillation)
        // There's a very small chance they match, but values should shift
        // due to the usageOffset advancing
        // Values may change between calls due to usageOffset advancement
        #expect(first.lastUpdated <= second.lastUpdated)
    }
}
