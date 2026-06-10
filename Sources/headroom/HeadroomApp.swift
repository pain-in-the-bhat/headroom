import SwiftUI

/// headroom — macOS menu bar app for OpenCode Go quota.
///
/// Shows used quota in your menu bar: each number colored independently
/// (green/amber/red based on threshold). Hover for window labels.
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
                .help("Rolling (5h) | Weekly | Monthly — used %")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Status Bar Label

/// Three colored numbers in the menu bar: `7` `2` `18`
/// Each number colored independently based on its usage threshold.
struct StatusBarLabel: View {
    @ObservedObject var service: QuotaPollingService

    var body: some View {
        switch service.state {
        case .loaded(let usage):
            coloredNumbers(usage: usage)
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

    @ViewBuilder
    private func coloredNumbers(usage: QuotaUsage) -> some View {
        HStack(spacing: 0) {
            numberText(usage.rolling?.usagePercent)
            separator
            numberText(usage.weekly?.usagePercent)
            separator
            numberText(usage.monthly?.usagePercent)
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
    }

    @ViewBuilder
    private func numberText(_ percent: Double?) -> some View {
        if let p = percent {
            Text("\(Int(p))")
                .foregroundColor(color(for: p))
        } else {
            Text("?")
                .foregroundColor(.secondary)
        }
    }

    private var separator: some View {
        Text("|")
            .foregroundColor(.secondary.opacity(0.4))
    }

    private func color(for percent: Double) -> Color {
        if percent < 30 { .green }
        else if percent < 70 { .orange }
        else { .red }
    }
}
