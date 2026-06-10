import SwiftUI

/// headroom — macOS menu bar app for OpenCode Go quota.
///
/// Shows the most-constrained window's used% in the menu bar.
/// One number. Glance, don't read. Hover for all three.
@main
struct HeadroomApp: App {

    @State private var service = QuotaPollingService()

    init() {
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

/// One number in the menu bar: the highest used% across all windows.
/// Colour tells you everything. Tooltip shows the full breakdown.
struct StatusBarLabel: View {
    @ObservedObject var service: QuotaPollingService

    var body: some View {
        switch service.state {
        case .loaded(let usage):
            compactNumber(usage: usage)
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

    /// Show only the worst window — the one closest to your limit.
    @ViewBuilder
    private func compactNumber(usage: QuotaUsage) -> some View {
        let windows = [usage.rolling, usage.weekly, usage.monthly].compactMap { $0 }
        let worst = windows.max(by: { $0.usagePercent < $1.usagePercent })

        if let w = worst {
            Text("\(Int(w.usagePercent))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(color(for: w.usagePercent))
                .help(tooltipText(usage: usage))
        } else {
            Text("?")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func tooltipText(usage: QuotaUsage) -> String {
        let r = usage.rolling.map { "R \(Int($0.usagePercent))%" } ?? "R ?"
        let w = usage.weekly.map  { "W \(Int($0.usagePercent))%" } ?? "W ?"
        let m = usage.monthly.map { "M \(Int($0.usagePercent))%" } ?? "M ?"
        return "\(r)  \(w)  \(m)"
    }

    private func color(for percent: Double) -> Color {
        if percent < 30 { .green }
        else if percent < 70 { .orange }
        else { .red }
    }
}
