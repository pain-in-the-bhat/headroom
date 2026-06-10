import Foundation

/// The three OpenCode Go quota windows.
public enum QuotaWindowType: String, Codable, CaseIterable, Sendable {
    case rolling
    case weekly
    case monthly

    public var displayName: String {
        switch self {
        case .rolling: return "Rolling (5h)"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    public var dashboardFieldName: String {
        rawValue + "Usage"
    }

    /// Human-readable label for the menu display
    public var shortLabel: String {
        switch self {
        case .rolling: return "R"
        case .weekly: return "W"
        case .monthly: return "M"
        }
    }
}
