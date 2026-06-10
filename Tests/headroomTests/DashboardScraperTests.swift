import Testing
import Foundation
@testable import headroom

/// Tests for the HTML dashboard scraper.
///
/// These tests use simulated HTML snippets that match the SolidJS SSR
/// hydration output format used by the OpenCode Go dashboard.
struct DashboardScraperTests {

    let decoder = ScrapedDataDecoder()

    // MARK: - Rolling Window

    @Test func testDecodeRollingUsagePercentFirst() throws {
        let html = """
        <script>window._$HY||...</script>
        <div>rollingUsage:$R[123]={usagePercent:42,resetInSec:7920,__debug:true}</div>
        <div>some more content</div>
        """
        let usage = try decoder.decode(html: html)
        #expect(usage.rolling != nil)
        #expect(usage.rolling?.usagePercent == 42)
        #expect(usage.rolling?.resetInSeconds == 7920)
        #expect(usage.rolling?.remainingPercent == 58)
    }

    @Test func testDecodeRollingResetFirst() throws {
        let html = """
        <script>rollingUsage:$R[456]={resetInSec:3600,usagePercent:15}</script>
        """
        let usage = try decoder.decode(html: html)
        #expect(usage.rolling != nil)
        #expect(usage.rolling?.usagePercent == 15)
        #expect(usage.rolling?.resetInSeconds == 3600)
        #expect(usage.rolling?.remainingPercent == 85)
    }

    // MARK: - Weekly Window

    @Test func testDecodeWeeklyUsage() throws {
        let html = """
        <div>weeklyUsage:$R[789]={usagePercent:67,resetInSec:259200}</div>
        """
        let usage = try decoder.decode(html: html)
        #expect(usage.weekly != nil)
        #expect(usage.weekly?.usagePercent == 67)
        #expect(usage.weekly?.resetInSeconds == 259200)
        #expect(usage.weekly?.remainingPercent == 33)
    }

    // MARK: - Monthly Window

    @Test func testDecodeMonthlyUsage() throws {
        let html = """
        <div>monthlyUsage:$R[101]={usagePercent:88,resetInSec:1036800}</div>
        """
        let usage = try decoder.decode(html: html)
        #expect(usage.monthly != nil)
        #expect(usage.monthly?.usagePercent == 88)
        #expect(usage.monthly?.resetInSeconds == 1036800)
        #expect(usage.monthly?.remainingPercent == 12)
    }

    // MARK: - All Windows

    @Test func testDecodeAllWindows() throws {
        let html = """
        <div>rollingUsage:$R[1]={usagePercent:10,resetInSec:1800}</div>
        <div>weeklyUsage:$R[2]={usagePercent:50,resetInSec:432000}</div>
        <div>monthlyUsage:$R[3]={usagePercent:90,resetInSec:864000}</div>
        """
        let usage = try decoder.decode(html: html)
        #expect(usage.rolling != nil)
        #expect(usage.weekly != nil)
        #expect(usage.monthly != nil)
        #expect(usage.isComplete)
        #expect(usage.hasLowWindow) // rolling at 90% remaining is fine, but monthly is at 10% remaining
        #expect(usage.monthly?.remainingPercent == 10)
    }

    // MARK: - Boundary and Error Cases

    @Test func testDecodeNoWindowsThrows() {
        let html = """
        <html><body>No quota data here</body></html>
        """
        #expect(throws: QuotaError.self) {
            try decoder.decode(html: html)
        }
    }

    @Test func testDecodePartialData() throws {
        let html = """
        <div>rollingUsage:$R[1]={usagePercent:25,resetInSec:900}</div>
        <!-- weeklyUsage is missing -->
        <!-- monthlyUsage is missing -->
        """
        let usage = try decoder.decode(html: html)
        #expect(usage.rolling != nil)
        #expect(usage.weekly == nil)
        #expect(usage.monthly == nil)
        #expect(!usage.isComplete)
    }

    @Test func testDecodeWithHTMLNoise() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>OpenCode</title>
        <script>
        window._$HY = {events:[],completed:new WeakSet,r:{},fe(){}};
        </script>
        </head>
        <body>
        <div id="app">
        <main data-hk="abc123">
        <section>
        <div>rollingUsage:$R[1]={usagePercent:5,resetInSec:300}</div>
        <div>weeklyUsage:$R[2]={usagePercent:20,resetInSec:604800}</div>
        <div>monthlyUsage:$R[3]={usagePercent:45,resetInSec:2592000}</div>
        </section>
        </main>
        </div>
        </body>
        </html>
        """
        let usage = try decoder.decode(html: html)
        #expect(usage.rolling?.usagePercent == 5)
        #expect(usage.weekly?.usagePercent == 20)
        #expect(usage.monthly?.usagePercent == 45)
    }

    @Test func testDecodeWithLargeResetValues() throws {
        let html = """
        <div>rollingUsage:$R[1]={usagePercent:0,resetInSec:0}</div>
        <div>monthlyUsage:$R[2]={usagePercent:100,resetInSec:9999999}</div>
        """
        let usage = try decoder.decode(html: html)
        #expect(usage.rolling?.usagePercent == 0)
        #expect(usage.rolling?.resetInSeconds == 0)
        #expect(usage.monthly?.usagePercent == 100)
        #expect(usage.monthly?.resetInSeconds == 9999999)
    }

    // MARK: - QuotaWindow Model

    @Test func testQuotaWindowExhausted() {
        let full = QuotaWindow(usagePercent: 95, resetInSeconds: 3600)
        #expect(full.isExhausted)
        #expect(full.remainingPercent == 5)

        let almost = QuotaWindow(usagePercent: 89, resetInSeconds: 3600)
        #expect(!almost.isExhausted)
    }

    @Test func testQuotaWindowLow() {
        let low = QuotaWindow(usagePercent: 75, resetInSeconds: 3600)
        #expect(low.isLow)

        let ok = QuotaWindow(usagePercent: 50, resetInSeconds: 3600)
        #expect(!ok.isLow)
    }

    @Test func testQuotaWindowClamping() {
        let over = QuotaWindow(usagePercent: 150, resetInSeconds: 3600)
        #expect(over.usagePercent == 100)
        #expect(over.remainingPercent == 0)

        let under = QuotaWindow(usagePercent: -10, resetInSeconds: 3600)
        #expect(under.usagePercent == 0)
        #expect(under.remainingPercent == 100)
    }
}
