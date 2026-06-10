import Foundation

/// Represents a single quota window (rolling, weekly, or monthly).
public struct QuotaWindow: Codable, Equatable, Sendable {
    /// Usage percentage, 0–100 (0 = no usage, 100 = fully consumed)
    public let usagePercent: Double

    /// Seconds until this window resets
    public let resetInSeconds: TimeInterval

    /// Percentage remaining (100 - usagePercent)
    public var remainingPercent: Double {
        100 - usagePercent
    }

    /// Whether the quota is exhausted (> 90% used)
    public var isExhausted: Bool {
        usagePercent >= 90
    }

    /// Whether the quota is getting low (> 70% used)
    public var isLow: Bool {
        usagePercent >= 70
    }

    public init(usagePercent: Double, resetInSeconds: TimeInterval) {
        self.usagePercent = max(0, min(100, usagePercent))
        self.resetInSeconds = max(0, resetInSeconds)
    }
}

/// Complete quota snapshot from OpenCode Go.
public struct QuotaUsage: Codable, Equatable, Sendable {
    public let rolling: QuotaWindow?
    public let weekly: QuotaWindow?
    public let monthly: QuotaWindow?
    public let lastUpdated: Date

    public init(rolling: QuotaWindow?, weekly: QuotaWindow?, monthly: QuotaWindow?, lastUpdated: Date = Date()) {
        self.rolling = rolling
        self.weekly = weekly
        self.monthly = monthly
        self.lastUpdated = lastUpdated
    }

    /// Whether all windows have data
    public var isComplete: Bool {
        rolling != nil && weekly != nil && monthly != nil
    }

    /// Whether any window is exhausted
    public var hasExhaustedWindow: Bool {
        rolling?.isExhausted == true || weekly?.isExhausted == true || monthly?.isExhausted == true
    }

    /// Whether any window is getting low
    public var hasLowWindow: Bool {
        rolling?.isLow == true || weekly?.isLow == true || monthly?.isLow == true
    }
}

/// Status of a quota fetch operation
public enum QuotaFetchResult: Equatable, Sendable {
    case success(QuotaUsage)
    case failure(QuotaError)

    public var usage: QuotaUsage? {
        if case .success(let u) = self { return u }
        return nil
    }

    public var error: QuotaError? {
        if case .failure(let e) = self { return e }
        return nil
    }
}

/// Errors that can occur during quota fetching.
public struct QuotaError: Error, Codable, Equatable, Sendable {
    public let message: String
    public let isAuthError: Bool
    public let isTransient: Bool

    public init(message: String, isAuthError: Bool = false, isTransient: Bool = true) {
        self.message = message
        self.isAuthError = isAuthError
        self.isTransient = isTransient
    }

    public static func auth(_ msg: String) -> QuotaError {
        QuotaError(message: msg, isAuthError: true, isTransient: false)
    }

    public static func network(_ msg: String) -> QuotaError {
        QuotaError(message: msg, isTransient: true)
    }

    public static func parse(_ msg: String) -> QuotaError {
        QuotaError(message: msg, isTransient: false)
    }
}
