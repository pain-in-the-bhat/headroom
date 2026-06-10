import SwiftUI
import AppKit

/// Dropdown menu content for headroom — read-only display + action buttons.
///
/// The Preferences sheet has been replaced with a standalone NSWindow
/// because MenuBarExtra popovers can't host sheets (they're transient
/// accessory panels, not full windows).
struct MenuBarView: View {

    @ObservedObject var service: QuotaPollingService

    public init(service: QuotaPollingService) {
        self.service = service
    }

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()

            contentView
                .padding(.horizontal, 12)

            Divider()

            footerView
        }
        .frame(width: 260)
        .onAppear {
            // Activate the app so the popover gets mouse/keyboard focus
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .foregroundColor(.accentColor)
            Text("headroom")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()

            if service.isStale, service.currentUsage != nil {
                HStack(spacing: 3) {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text("stale").font(.caption2).foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch service.state {
        case .initial:
            initialView
        case .loading:
            loadingView
        case .loaded(let usage):
            quotaDetailView(usage: usage)
        case .failed(let error):
            errorView(error: error)
        }
    }

    private var initialView: some View {
        VStack(spacing: 10) {
            Image(systemName: "gearshape")
                .font(.title2)
                .foregroundColor(.secondary)
                .padding(.top, 10)

            Text("Not Configured")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Set workspace ID and auth cookie\nin Preferences to start.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                ProgressView().scaleEffect(0.8)
                Text("Fetching...").font(.caption).foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
            Spacer()
        }
    }

    @ViewBuilder
    private func quotaDetailView(usage: QuotaUsage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let r = usage.rolling { windowRow(type: .rolling, window: r) }
            if let w = usage.weekly { windowRow(type: .weekly, window: w) }
            if let m = usage.monthly { windowRow(type: .monthly, window: m) }

            HStack {
                Spacer()
                if let lastFetch = service.lastFetchTime {
                    Text("Updated: \(lastFetch, formatter: timeFormatter)")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func windowRow(type: QuotaWindowType, window: QuotaWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 6) {
                    Text(type.shortLabel)
                        .font(.caption2).fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(remainingColor(window.remainingPercent))
                        .cornerRadius(4)
                    Text(type.displayName)
                        .font(.subheadline).fontWeight(.medium)
                }
                Spacer()
                Text("\(Int(window.remainingPercent))%")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(remainingColor(window.remainingPercent))
            }

            ProgressView(value: window.remainingPercent / 100)
                .tint(remainingColor(window.remainingPercent))

            Text("Resets in: \(DurationFormatter.verbose(seconds: window.resetInSeconds))")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func errorView(error: QuotaError) -> some View {
        VStack(spacing: 8) {
            Image(systemName: error.isAuthError ? "key.slash.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(error.isAuthError ? .orange : .red)
                .padding(.top, 8)

            Text(error.isAuthError ? "Auth Error" : "Error")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(error.isAuthError ? .orange : .red)

            Text(error.message)
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center).lineLimit(4)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 0) {
            MenuBarButton(icon: "arrow.clockwise", title: "Refresh",
                          disabled: service.isFetching) {
                Task { await service.fetchNow() }
            }
            .disabled(service.isFetching)

            MenuBarButton(icon: "globe", title: "Open Dashboard") {
                NSWorkspace.shared.open(URL(string: "https://opencode.ai")!)
            }

            Divider()

            MenuBarButton(icon: "gearshape", title: "Preferences...") {
                showPreferences()
            }

            Divider()

            MenuBarButton(icon: "power", title: "Quit headroom",
                          isDestructive: true) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    // MARK: - Helpers

    private var preferencesController = PreferencesWindowControllerRef()

    private func showPreferences() {
        let controller = PreferencesWindowController(service: service)
        controller.show()
        // Keep a reference so the window isn't deallocated
        preferencesController.store(controller)
    }

    private func remainingColor(_ percent: Double) -> Color {
        if percent < 10 { .red } else if percent < 30 { .orange } else { .green }
    }
}

// MARK: - Reference Holder

/// Holds a strong reference to the PreferencesWindowController so it
/// stays alive after the function scope exits.
final class PreferencesWindowControllerRef {
    private var controller: PreferencesWindowController?

    func store(_ c: PreferencesWindowController) {
        controller = c
    }
}

// MARK: - Menu Bar Button

struct MenuBarButton: View {
    let icon: String
    let title: String
    var disabled = false
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).frame(width: 16)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
            .foregroundColor(isDestructive ? .red : .primary)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
