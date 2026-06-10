import SwiftUI

/// headroom — macOS menu bar app for OpenCode Go quota.
///
/// Shows remaining quota in your menu bar: `OC 62|41|18`
@main
struct HeadroomApp: App {

    @State private var service = QuotaPollingService()

    init() {
        // Required for a menu bar app: tells macOS this is a background app
        // (no Dock icon) and that it should handle activation properly.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(service: service)
        } label: {
            StatusBarLabel(service: service)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Status Bar Label

/// The dynamic status bar label: "OC 62|41|18"
struct StatusBarLabel: View {
    @ObservedObject var service: QuotaPollingService

    var body: some View {
        HStack(spacing: 2) {
            Text("OC")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)

            statusText
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch service.state {
        case .loaded(let usage):
            statusLabel(for: usage)
        case .loading:
            Text("...")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        case .failed:
            Text("ERR")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.red)
        case .initial:
            Text("--")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
    }

    private func statusLabel(for usage: QuotaUsage) -> Text {
        let rolling = usage.rolling.map { "\(Int($0.remainingPercent))" } ?? "?"
        let weekly = usage.weekly.map { "\(Int($0.remainingPercent))" } ?? "?"
        let monthly = usage.monthly.map { "\(Int($0.remainingPercent))" } ?? "?"
        let text = "\(rolling)|\(weekly)|\(monthly)"
        return Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
    }
}
