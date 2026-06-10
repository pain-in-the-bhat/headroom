import Testing
import Foundation
@testable import headroom

/// Tests for the duration formatter utility.
struct DurationFormatterTests {

    @Test func testFormatSeconds() {
        #expect(DurationFormatter.format(seconds: 30) == "30s")
        #expect(DurationFormatter.format(seconds: 60) == "1m")
        #expect(DurationFormatter.format(seconds: 120) == "2m")
        #expect(DurationFormatter.format(seconds: 3600) == "1h 0m")
        #expect(DurationFormatter.format(seconds: 3661) == "1h 1m")
        #expect(DurationFormatter.format(seconds: 7200) == "2h 0m")
        #expect(DurationFormatter.format(seconds: 86400) == "1d 0h")
        #expect(DurationFormatter.format(seconds: 90000) == "1d 1h")
        #expect(DurationFormatter.format(seconds: 172800) == "2d 0h")
        #expect(DurationFormatter.format(seconds: 0) == "0s")
    }

    @Test func testFormatVerbose() {
        #expect(DurationFormatter.verbose(seconds: 30) == "0m")
        #expect(DurationFormatter.verbose(seconds: 3661) == "1h 1m")
        #expect(DurationFormatter.verbose(seconds: 90000) == "1d 1h")
        #expect(DurationFormatter.verbose(seconds: 7200) == "2h")
        #expect(DurationFormatter.verbose(seconds: 0) == "0m")
        #expect(DurationFormatter.verbose(seconds: 120) == "2m")
    }

    @Test func testFormatEdgeCases() {
        #expect(DurationFormatter.format(seconds: -10) == "0s")
        #expect(DurationFormatter.format(seconds: 1) == "1s")
        #expect(DurationFormatter.format(seconds: 59) == "59s")
        #expect(DurationFormatter.format(seconds: 86399) == "23h 59m")
        #expect(DurationFormatter.format(seconds: 604800) == "7d 0h")
    }
}
