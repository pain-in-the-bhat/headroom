import Foundation

/// Stores credentials in `~/.config/headroom/config.json`.
///
/// Replaces Keychain storage which requires Developer ID signing and
/// triggers intrusive permission dialogs on ad-hoc signed builds.
/// This is the same approach used by slkiser/opencode-quota and
/// pi-go-bars — standard for CLI/dev tools.
///
/// File format:
/// ```json
/// {
///   "workspaceId": "wrk_xxx",
///   "authCookie": "xxx",
///   "apiKey": null,
///   "fetchStrategy": "scraping"
/// }
/// ```
public actor CredentialStore {

    public enum StoreError: Error, LocalizedError {
        case writeFailed(String)
        case readFailed(String)
        case unexpectedFormat

        public var errorDescription: String? {
            switch self {
            case .writeFailed(let msg): return "Failed to save: \(msg)"
            case .readFailed(let msg): return "Failed to read: \(msg)"
            case .unexpectedFormat: return "Config file has unexpected format"
            }
        }
    }

    private let configDir: URL
    private let configFile: URL

    private struct ConfigFile: Codable {
        var workspaceId: String?
        var authCookie: String?
        var apiKey: String?
        var fetchStrategy: String?
    }

    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configDir = home.appendingPathComponent(".config/headroom")
        self.configFile = configDir.appendingPathComponent("config.json")
    }

    // MARK: - Public API

    /// Store OpenCode credentials.
    public func store(credentials: OpenCodeCredentials) throws {
        var config = (try? readConfig()) ?? ConfigFile()
        config.workspaceId = credentials.workspaceId
        config.authCookie = credentials.authCookie
        config.apiKey = credentials.apiKey
        try writeConfig(config)
    }

    /// Read stored credentials.
    /// - Returns: `OpenCodeCredentials` if found, `nil` if not configured.
    public func read() throws -> OpenCodeCredentials? {
        guard let config = try? readConfig() else { return nil }
        guard let workspaceId = config.workspaceId, !workspaceId.isEmpty,
              let authCookie = config.authCookie, !authCookie.isEmpty else {
            return nil
        }
        return OpenCodeCredentials(
            workspaceId: workspaceId,
            authCookie: authCookie,
            apiKey: config.apiKey
        )
    }

    /// Delete all stored credentials.
    public func deleteAll() throws {
        try? FileManager.default.removeItem(at: configFile)
    }

    /// Whether credentials are stored.
    public func hasCredentials() -> Bool {
        (try? read()) != nil
    }

    /// Store fetch strategy preference.
    public func store(strategy: FetchStrategy) throws {
        var config = (try? readConfig()) ?? ConfigFile()
        config.fetchStrategy = strategy.rawValue
        try writeConfig(config)
    }

    /// Read stored fetch strategy.
    public func readStrategy() -> FetchStrategy {
        guard let config = try? readConfig(),
              let raw = config.fetchStrategy,
              let strategy = FetchStrategy(rawValue: raw) else {
            return .auto
        }
        return strategy
    }

    // MARK: - File I/O

    private func readConfig() throws -> ConfigFile {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            return ConfigFile()
        }
        do {
            let data = try Data(contentsOf: configFile)
            let decoder = JSONDecoder()
            return try decoder.decode(ConfigFile.self, from: data)
        } catch is DecodingError {
            throw StoreError.unexpectedFormat
        } catch {
            throw StoreError.readFailed(error.localizedDescription)
        }
    }

    private func writeConfig(_ config: ConfigFile) throws {
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        // Atomic write: write to temp, then rename
        let tempFile = configFile.appendingPathExtension("tmp")
        try data.write(to: tempFile, options: .atomic)
        try? FileManager.default.removeItem(at: configFile)
        try FileManager.default.moveItem(at: tempFile, to: configFile)
    }
}
