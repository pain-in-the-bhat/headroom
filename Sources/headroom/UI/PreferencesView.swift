import SwiftUI

/// Preferences / Settings view for configuring credentials.
///
/// Hosted in a standalone NSWindow (PreferencesWindowController), not a sheet.
/// Sheets from MenuBarExtra popovers are broken — they can't get keyboard focus.
struct PreferencesView: View {

    @ObservedObject var service: QuotaPollingService
    var onDismiss: (() -> Void)? = nil

    @State private var workspaceId: String = ""
    @State private var authCookie: String = ""
    @State private var apiKey: String = ""
    @State private var refreshInterval: Double = 60
    @State private var selectedStrategy: FetchStrategy = .auto

    @State private var statusMessage: String = ""
    @State private var statusIsError: Bool = false
    @State private var isTesting = false

    private let store = CredentialStore()

    var body: some View {
        TabView {
            credentialsTab
                .tabItem {
                    Label("Credentials", systemImage: "key.fill")
                }

            settingsTab
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 320)
        .onAppear {
            refreshInterval = service.refreshInterval
            selectedStrategy = service.strategy
        }
    }

    // MARK: - Credentials Tab

    private var credentialsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("OpenCode Go Credentials")
                .font(.headline)

            Text("To find these values, visit opencode.ai → Your Workspace → Go.")
                .font(.caption)
                .foregroundColor(.secondary)

            // Workspace ID
            VStack(alignment: .leading, spacing: 4) {
                Text("Workspace ID").font(.subheadline).fontWeight(.medium)
                TextField("e.g. wrk_xxxxxxxxxxxx", text: $workspaceId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("From URL: https://opencode.ai/workspace/{id}/go")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Auth Cookie
            VStack(alignment: .leading, spacing: 4) {
                Text("Auth Cookie").font(.subheadline).fontWeight(.medium)
                SecureField("auth cookie value", text: $authCookie)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("From browser DevTools → Application → Cookies → opencode.ai → auth")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // API Key (optional, for future use)
            VStack(alignment: .leading, spacing: 4) {
                Text("API Key (optional)").font(.subheadline).fontWeight(.medium)
                SecureField("For future API-based fetching", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            // Status message
            if !statusMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: statusIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(statusIsError ? .red : .green)
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(statusIsError ? .red : .secondary)
                }
            }

            // Action buttons
            HStack {
                Button("Load Saved") {
                    loadSavedCredentials()
                }
                .disabled(isTesting)

                Button("Test Connection") {
                    testConnection()
                }
                .disabled(isTesting || workspaceId.isEmpty || authCookie.isEmpty)

                Spacer()

                Button("Save") {
                    saveCredentials()
                }
                .disabled(workspaceId.isEmpty || authCookie.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        Form {
            Section("Polling") {
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $refreshInterval, in: 15...300, step: 15) {
                        Text("Refresh Interval: \(Int(refreshInterval))s")
                    }
                    Text("How often to check for updated quota. \(Int(refreshInterval)) seconds.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Fetch Strategy") {
                Picker("Data Source", selection: $selectedStrategy) {
                    ForEach(FetchStrategy.allCases, id: \.self) { strategy in
                        Text(strategyLabel(strategy)).tag(strategy)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(strategyDescription(selectedStrategy))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Clear All Credentials") {
                        clearCredentials()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)

            Text("headroom")
                .font(.title2)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label("Monitors OpenCode Go subscription quota", systemImage: "1.circle")
                Label("Rolling (5h), Weekly, Monthly windows", systemImage: "2.circle")
                Label("Credential storage in ~/.config/headroom/", systemImage: "3.circle")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Spacer()

            Text("Built by @PainInTheBhat")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadSavedCredentials() {
        Task {
            do {
                if let credentials = try await store.read() {
                    workspaceId = credentials.workspaceId
                    authCookie = credentials.authCookie
                    apiKey = credentials.apiKey ?? ""
                statusMessage = "Credentials loaded from config file."
                statusIsError = false
            } else {
                statusMessage = "No saved credentials found."
                statusIsError = false
            }
        } catch {
            statusMessage = "Could not read config: \(error.localizedDescription)"
            statusIsError = true
        }
        }
    }

    private func saveCredentials() {
        let credentials = OpenCodeCredentials(
            workspaceId: workspaceId.trimmingCharacters(in: .whitespacesAndNewlines),
            authCookie: authCookie.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        service.configure(credentials: credentials, strategy: selectedStrategy)
        service.refreshInterval = refreshInterval
        service.startPolling()

        statusMessage = "Credentials saved successfully."
        statusIsError = false
        onDismiss?()
    }

    private func testConnection() {
        guard !workspaceId.isEmpty, !authCookie.isEmpty else {
            statusMessage = "Please enter both Workspace ID and Auth Cookie."
            statusIsError = true
            return
        }

        isTesting = true
        statusMessage = "Testing connection..."

        Task {
            let testCredentials = OpenCodeCredentials(
                workspaceId: workspaceId.trimmingCharacters(in: .whitespacesAndNewlines),
                authCookie: authCookie.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let fetcher = ScrapingQuotaFetcher(credentials: testCredentials)

            do {
                let usage = try await fetcher.fetch()
                await MainActor.run {
                    statusMessage = "Connected! Rolling: \(Int(usage.rolling?.remainingPercent ?? 0))%, Weekly: \(Int(usage.weekly?.remainingPercent ?? 0))%, Monthly: \(Int(usage.monthly?.remainingPercent ?? 0))%"
                    statusIsError = false
                    isTesting = false
                }
            } catch let error as QuotaError {
                await MainActor.run {
                    statusMessage = error.message
                    statusIsError = true
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                    statusIsError = true
                    isTesting = false
                }
            }
        }
    }

    private func clearCredentials() {
        Task {
            await service.reset()
            workspaceId = ""
            authCookie = ""
            apiKey = ""
            statusMessage = "Credentials cleared."
            statusIsError = false
        }
    }

    // MARK: - Helpers

    private func strategyLabel(_ strategy: FetchStrategy) -> String {
        switch strategy {
        case .auto: return "Auto (try API, fall back to scraping)"
        case .scraping: return "Dashboard Scraping (current)"
        case .api: return "API Endpoint (future)"
        case .mock: return "Mock Data (testing)"
        }
    }

    private func strategyDescription(_ strategy: FetchStrategy) -> String {
        switch strategy {
        case .auto:
            return "Attempts the official API first. If unavailable, falls back to dashboard scraping."
        case .scraping:
            return "Fetches quota from the OpenCode Go dashboard using your auth cookie. This is the current recommended approach."
        case .api:
            return "Uses the /zen/go/v1/usage API endpoint. Not yet available — track PR #16513."
        case .mock:
            return "Generates random but realistic quota data for testing the UI."
        }
    }
}
