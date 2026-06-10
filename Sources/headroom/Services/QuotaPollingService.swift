import Foundation
import Combine

/// Possible states for the polling service.
public enum PollingState: Equatable, Sendable {
    /// Initial state, not yet fetched
    case initial
    /// Fetch in progress
    case loading
    /// Successfully loaded quota data
    case loaded(QuotaUsage)
    /// Fetch failed with error
    case failed(QuotaError)
}

/// Manages periodic fetching of OpenCode Go quota data.
///
/// This is the central coordinator that:
/// 1. Holds the current quota state (published for UI observation)
/// 2. Runs a timer at the configured interval
/// 3. Routes requests through the appropriate fetcher implementation
/// 4. Handles error backoff and stale data detection
@MainActor
public final class QuotaPollingService: ObservableObject {

    // MARK: - Published State

    /// Current polling state
    @Published public private(set) var state: PollingState = .initial

    /// When the last successful fetch occurred
    @Published public private(set) var lastFetchTime: Date?

    /// Whether a fetch is currently in progress
    @Published public private(set) var isFetching = false

    /// The fetch strategy currently in use
    @Published public private(set) var strategy: FetchStrategy = .auto

    /// Configured polling interval in seconds
    @Published public var refreshInterval: TimeInterval = 60 {
        didSet { resetTimer() }
    }

    // MARK: - Private Properties

    private var fetcher: QuotaFetcher?
    private var keychain: KeychainController
    private var timer: Timer?
    private var failureCount = 0
    private var isConfigured = false

    // Error backoff constants
    private let baseBackoff: TimeInterval = 30
    private let maxBackoff: TimeInterval = 900 // 15 minutes

    // MARK: - Initialization

    public init(keychain: KeychainController = KeychainController()) {
        self.keychain = keychain
    }

    // MARK: - Public API

    /// Configure the service with new credentials and strategy.
    /// - Parameters:
    ///   - credentials: OpenCode credentials (workspaceId + authCookie)
    ///   - strategy: Fetch strategy (auto, scraping, api, mock)
    public func configure(credentials: OpenCodeCredentials, strategy: FetchStrategy = .auto) {
        self.strategy = strategy
        self.fetcher = makeFetcher(credentials: credentials, strategy: strategy)
        self.isConfigured = true
        self.failureCount = 0
        Task { await storeCredentials(credentials, strategy: strategy) }
    }

    /// Configure using stored credentials (from Keychain).
    /// - Returns: Whether credentials were found and loaded.
    public func configureFromKeychain() async -> Bool {
        guard let credentials = try? await keychain.read() else {
            return false
        }
        let storedStrategy = await keychain.readStrategy()
        self.strategy = storedStrategy
        self.fetcher = makeFetcher(credentials: credentials, strategy: storedStrategy)
        self.isConfigured = true
        self.failureCount = 0
        return true
    }

    /// Start the polling timer.
    public func startPolling() {
        // Fire immediately, then on interval
        Task { await fetchNow() }
        resetTimer()
    }

    /// Stop the polling timer.
    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    /// Force an immediate fetch.
    public func fetchNow() async {
        guard !isFetching else { return }
        isFetching = true

        if state == .initial {
            state = .loading
        }

        do {
            guard let fetcher = fetcher else {
                throw QuotaError.auth("Not configured — please set workspace ID and auth cookie in Preferences")
            }

            let usage = try await fetcher.fetch()
            state = .loaded(usage)
            lastFetchTime = Date()
            failureCount = 0
        } catch let error as QuotaError {
            state = .failed(error)
            failureCount += 1
        } catch {
            state = .failed(QuotaError.network(error.localizedDescription))
            failureCount += 1
        }

        isFetching = false
    }

    /// Whether credentials are stored and the service is ready.
    public var ready: Bool {
        isConfigured && fetcher != nil
    }

    /// Clear all credentials and reset state.
    public func reset() async {
        stopPolling()
        fetcher = nil
        isConfigured = false
        state = .initial
        lastFetchTime = nil
        failureCount = 0
        try? await keychain.deleteAll()
    }

    // MARK: - Private

    private func makeFetcher(credentials: OpenCodeCredentials, strategy: FetchStrategy) -> QuotaFetcher {
        switch strategy {
        case .mock:
            return MockQuotaFetcher()
        case .api:
            // Placeholder — API not yet available
            return APIQuotaFetcher(apiKey: credentials.apiKey ?? "")
        case .scraping, .auto:
            return ScrapingQuotaFetcher(
                credentials: credentials,
                scraper: DashboardScraper()
            )
        }
    }

    private func resetTimer() {
        timer?.invalidate()
        let interval: TimeInterval
        if failureCount > 0 {
            // Exponential backoff on failures
            let backoff = min(baseBackoff * pow(2.0, Double(failureCount - 1)), maxBackoff)
            interval = min(backoff, refreshInterval)
        } else {
            interval = refreshInterval
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { [weak self] in
                await self?.fetchNow()
                await self?.resetTimer() // Re-schedule for the next interval
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func storeCredentials(_ credentials: OpenCodeCredentials, strategy: FetchStrategy) async {
        try? await keychain.store(credentials: credentials)
        try? await keychain.store(strategy: strategy)
    }
}

// MARK: - QuotaUsage Convenience Accessors

extension QuotaPollingService {
    /// The current quota usage, if loaded.
    public var currentUsage: QuotaUsage? {
        if case .loaded(let usage) = state { return usage }
        return nil
    }

    /// The current error, if any.
    public var currentError: QuotaError? {
        if case .failed(let error) = state { return error }
        return nil
    }

    /// Whether data is stale (> 5 minutes since last fetch).
    public var isStale: Bool {
        guard let lastFetch = lastFetchTime else { return true }
        return Date().timeIntervalSince(lastFetch) > 300
    }
}
