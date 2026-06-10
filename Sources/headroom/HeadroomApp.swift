import SwiftUI

/// headroom — macOS menu bar app for OpenCode Go quota.
///
/// Shows used quota in your menu bar: `7|2|18`
/// (rolling | weekly | monthly — lower is better)
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

/// Raw numbers in the menu bar: `7|2|18` (rolling | weekly | monthly used %)
struct StatusBarLabel: View {
    @ObservedObject var service: QuotaPollingService

    var body: some View {
        statusText
    }

    @ViewBuilder
    private var statusText: some View {
        switch service.state {
        case .loaded(let usage):
            let rolling  = usage.rolling.map  { "\(Int($0.usagePercent))" } ?? "?"
            let weekly   = usage.weekly.map   { "\(Int($0.usagePercent))" } ?? "?"
            let monthly  = usage.monthly.map  { "\(Int($0.usagePercent))" } ?? "?"
            Text("\(rolling)|\(weekly)|\(monthly)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
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
}
