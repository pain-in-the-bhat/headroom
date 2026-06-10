import Testing
import Foundation
@testable import headroom

/// Tests for the QuotaError and QuotaFetchResult types.
struct QuotaErrorTests {

    @Test func testAuthError() {
        let error = QuotaError.auth("Cookie expired")
        #expect(error.isAuthError)
        #expect(!error.isTransient)
        #expect(error.message == "Cookie expired")
    }

    @Test func testNetworkError() {
        let error = QuotaError.network("Connection failed")
        #expect(!error.isAuthError)
        #expect(error.isTransient)
        #expect(error.message == "Connection failed")
    }

    @Test func testParseError() {
        let error = QuotaError.parse("Unexpected format")
        #expect(!error.isAuthError)
        #expect(!error.isTransient)
        #expect(error.message == "Unexpected format")
    }

    @Test func testFetchResultSuccess() {
        let usage = QuotaUsage(
            rolling: QuotaWindow(usagePercent: 50, resetInSeconds: 3600),
            weekly: nil,
            monthly: nil
        )
        let result = QuotaFetchResult.success(usage)
        #expect(result.usage != nil)
        #expect(result.error == nil)
        #expect(result.usage?.rolling?.usagePercent == 50)
    }

    @Test func testFetchResultFailure() {
        let error = QuotaError.auth("Invalid credentials")
        let result = QuotaFetchResult.failure(error)
        #expect(result.usage == nil)
        #expect(result.error != nil)
        #expect(result.error?.isAuthError == true)
    }
}
