import Foundation
import Security

/// Manages secure storage of OpenCode credentials using the macOS Keychain.
///
/// Credentials are stored as generic passwords with a service name and
/// account label, scoped to the current application only.
public actor KeychainController {

    public enum KeychainError: Error, LocalizedError {
        case storeFailed(OSStatus)
        case readFailed(OSStatus)
        case deleteFailed(OSStatus)
        case unexpectedData
        case notFound

        public var errorDescription: String? {
            switch self {
            case .storeFailed(let status): return "Failed to store credentials (OSStatus: \(status))"
            case .readFailed(let status): return "Failed to read credentials (OSStatus: \(status))"
            case .deleteFailed(let status): return "Failed to delete credentials (OSStatus: \(status))"
            case .unexpectedData: return "Unexpected credential data format"
            case .notFound: return "No credentials found in Keychain"
            }
        }
    }

    private let serviceName = "com.paininthehat.headroom"
    private let workspaceAccount = "workspaceId"
    private let authCookieAccount = "authCookie"
    private let apiKeyAccount = "apiKey"
    private let strategyAccount = "fetchStrategy"

    public init() {}

    // MARK: - Public API

    /// Store OpenCode credentials in Keychain.
    public func store(credentials: OpenCodeCredentials) throws {
        try store(value: credentials.workspaceId, account: workspaceAccount)
        try store(value: credentials.authCookie, account: authCookieAccount)
        if let apiKey = credentials.apiKey {
            try store(value: apiKey, account: apiKeyAccount)
        } else {
            // If apiKey is nil, remove any existing value
            try? delete(account: apiKeyAccount)
        }
    }

    /// Read stored credentials from Keychain.
    /// - Returns: `OpenCodeCredentials` if found, `nil` if not configured.
    public func read() throws -> OpenCodeCredentials? {
        guard let workspaceId = try read(account: workspaceAccount) else {
            return nil
        }
        guard let authCookie = try read(account: authCookieAccount) else {
            return nil
        }
        let apiKey = try read(account: apiKeyAccount)
        return OpenCodeCredentials(workspaceId: workspaceId, authCookie: authCookie, apiKey: apiKey)
    }

    /// Delete all stored credentials.
    public func deleteAll() throws {
        try? delete(account: workspaceAccount)
        try? delete(account: authCookieAccount)
        try? delete(account: apiKeyAccount)
        try? delete(account: strategyAccount)
    }

    /// Whether credentials are stored in Keychain.
    public func hasCredentials() -> Bool {
        (try? read()) != nil
    }

    /// Store fetch strategy preference.
    public func store(strategy: FetchStrategy) throws {
        try store(value: strategy.rawValue, account: strategyAccount)
    }

    /// Read stored fetch strategy.
    /// - Returns: The stored strategy, or `.auto` if not configured.
    public func readStrategy() -> FetchStrategy {
        guard let raw = try? read(account: strategyAccount),
              let strategy = FetchStrategy(rawValue: raw) else {
            return .auto
        }
        return strategy
    }

    // MARK: - Keychain Operations

    private func store(value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.storeFailed(errSecDecode)
        }

        // Delete existing item first
        try? delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    private func read(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedData
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.readFailed(status)
        }
    }

    private func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
