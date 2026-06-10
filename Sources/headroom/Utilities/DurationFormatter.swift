import Foundation

/// Formats time intervals into human-readable reset countdowns.
public enum DurationFormatter {

    /// Format seconds into a compact human-readable string.
    /// Examples: "2h 13m", "3d 4h", "12d 6h", "45m", "30s"
    public static func format(seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(0, seconds))

        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(secs)s"
        }
    }

    /// Format seconds into a verbose human-readable string.
    /// Examples: "2 hours, 13 minutes", "3 days, 4 hours"
    public static func verbose(seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(0, seconds))
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 || parts.isEmpty { parts.append("\(minutes)m") }

        return parts.joined(separator: " ")
    }
}
