import SwiftUI
import AppKit

/// Dropdown panel for headroom — fuel-gauge aesthetic.
///
/// Compact readout panel, not a traditional menu. Thin horizontal
/// runway bars, minimal chrome, text-only actions.
struct MenuBarView: View {

    @ObservedObject var service: QuotaPollingService

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    public init(service: QuotaPollingService) {
        self.service = service
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().opacity(0.3)
            contentView
                .padding(.horizontal, 14)
            Divider().opacity(0.3)
            footerView
        }
        .frame(width: 260)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("hr")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .tracking(1)

            Spacer()

            if service.isStale, service.currentUsage != nil {
                Circle().fill(.orange).frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch service.state {
        case .initial:
            emptyView
        case .loading:
            loadingView
        case .loaded(let usage):
            quotaView(usage: usage)
        case .failed(let error):
            errorView(error: error)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Text("Not configured")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.top, 14)

            Text("Open Preferences to set up.")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.7)
                .padding(.vertical, 20)
            Spacer()
        }
    }

    @ViewBuilder
    private func quotaView(usage: QuotaUsage) -> some View {
        VStack(spacing: 14) {
            if let r = usage.rolling { runwayRow(type: .rolling, window: r) }
            if let w = usage.weekly  { runwayRow(type: .weekly,  window: w) }
            if let m = usage.monthly { runwayRow(type: .monthly, window: m) }

            // Timestamp
            if let lastFetch = service.lastFetchTime {
                HStack {
                    Spacer()
                    Text("updated \(lastFetch, formatter: timeFormatter)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Runway Row

    @ViewBuilder
    private func runwayRow(type: QuotaWindowType, window: QuotaWindow) -> some View {
        let c = color(for: window.usagePercent)

        VStack(alignment: .leading, spacing: 4) {
            // Label + used%
            HStack(alignment: .firstTextBaseline) {
                Text(type.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(window.usagePercent))")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(c)
                    Text("%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(c.opacity(0.6))
                        .padding(.leading, 1)
                }
            }

            // Runway bar — 4px tall, rounded, left-to-right fill
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(c.opacity(0.12))
                        .frame(height: 4)

                    // Fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(c)
                        .frame(width: max(4, geo.size.width * window.usagePercent / 100), height: 4)
                        .animation(.easeInOut(duration: 0.6), value: window.usagePercent)
                }
            }
            .frame(height: 4)

            // Reset timer
            HStack {
                Text("\(Int(window.remainingPercent))% remaining")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))

                Text("· resets \(DurationFormatter.verbose(seconds: window.resetInSeconds))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
    }

    // MARK: - Error

    @ViewBuilder
    private func errorView(error: QuotaError) -> some View {
        VStack(spacing: 8) {
            Text(error.isAuthError ? "Auth error" : "Error")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(error.isAuthError ? .orange : .red)
                .padding(.top, 12)

            Text(error.message)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.bottom, 12)

            Button("Reconfigure") {
                showPreferences()
            }
            .font(.system(size: 11))
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                actionButton("Refresh") { Task { await service.fetchNow() } }
                    .disabled(service.isFetching)
                Text("·").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.3)).padding(.horizontal, 4)
                actionButton("Dashboard") {
                    NSWorkspace.shared.open(URL(string: "https://opencode.ai")!)
                }
                Spacer()
                actionButton("Prefs") { showPreferences() }
                Text("·").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.3)).padding(.horizontal, 4)
                actionButton("Quit") { NSApplication.shared.terminate(nil) }
                    .foregroundColor(.red.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
        }
    }

    // MARK: - Helpers

    private func actionButton(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .buttonStyle(.plain)
        .opacity(0.6)
    }

    private var preferencesController = PreferencesWindowControllerRef()

    private func showPreferences() {
        let controller = PreferencesWindowController(service: service)
        controller.show()
        preferencesController.store(controller)
    }

    private func color(for percent: Double) -> Color {
        if percent < 30 { .green }
        else if percent < 70 { .orange }
        else { .red }
    }
}

// MARK: - Reference Holder

/// Holds a strong reference to PreferencesWindowController.
final class PreferencesWindowControllerRef {
    private var controller: PreferencesWindowController?
    func store(_ c: PreferencesWindowController) { controller = c }
}
