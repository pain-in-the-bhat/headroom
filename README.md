<p align="center">
  <picture>
    <source srcset="https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple" media="(prefers-color-scheme: dark)">
    <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple">
  </picture>
  <a href="https://github.com/pain-in-the-bhat/headroom/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/pain-in-the-bhat/headroom/ci.yml?style=flat-square&branch=main&label=CI"></a>
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square"></a>
</p>

<p align="center"><strong>headroom</strong> — OpenCode Go quota in your macOS menu bar.</p>

```
85
```

One number. Your rolling (5h) window — the one that changes your next hour. Green when calm, red when you're about to hit a limit. Hover for all three.

---

## What you get

- **One number in your menu bar.** Shows your rolling (5h) window — the most time-sensitive limit. Falls back to weekly/monthly if rolling isn't available. Colour-coded (green < 30%, amber 30–70%, red > 70%). Hover for full breakdown.
- **Dropdown panel:** Thin fuel-gauge bars, reset timers, compact text-only actions.
- **60s auto-refresh** with exponential backoff on errors.
- **Standalone Preferences window** — no broken sheets, no hidden Keychain prompts.
- **Provider abstraction:** Dashboard scraping today, API endpoint when [PR #16513](https://github.com/anomalyco/opencode/pull/16513) ships.

## Quick setup

1. **Open Preferences** from the menu bar dropdown.
2. **Workspace ID** — from your workspace URL: `https://opencode.ai/workspace/{id}/go`
3. **Auth Cookie:**
   - **Safari:** Settings → Advanced → "Show Develop menu" → Develop → Show Web Inspector → Storage → Cookies → `opencode.ai` → copy `auth`
   - **Chrome:** DevTools (F12) → Application → Storage → Cookies → `opencode.ai` → copy `auth`
4. **Click Save.** Polling starts immediately. Credentials stored at `~/.config/headroom/config.json`.

## Download

Grab the latest `headroom.zip` from [Releases](https://github.com/pain-in-the-bhat/headroom/releases), unzip, and move `headroom.app` to `/Applications`.

**First launch:** macOS Gatekeeper will block it since the app isn't signed with an Apple Developer ID. Right-click the app → **Open** (or run `xattr -cr headroom.app` in Terminal). You only need to do this once.

## Build

```bash
git clone https://github.com/pain-in-the-bhat/headroom.git
cd headroom
./bundle.sh && open build/headroom.app
```

Or open `Package.swift` in Xcode and hit ⌘R.

## Test

```bash
swift test
```

25 tests covering HTML scraping, mock data generation, duration formatting, and error types.

## Configuration

Settings are stored in `~/.config/headroom/config.json`:

```json
{
  "workspaceId": "wrk_xxx",
  "authCookie": "xxx",
  "fetchStrategy": "scraping"
}
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `fetchStrategy` | `scraping` | `scraping` (dashboard), `api` (future endpoint), `mock` (testing) |
| Refresh interval | 60s | Configurable 15–300s in Preferences |

## Architecture

```
headroom/
├── Sources/headroom/
│   ├── HeadroomApp.swift              # @main + coloured status bar label
│   ├── Models/
│   │   ├── QuotaUsage.swift           # Core data types
│   │   └── QuotaWindowType.swift      # Rolling/Weekly/Monthly enums
│   ├── Providers/
│   │   ├── QuotaFetcher.swift          # Provider protocol
│   │   ├── ScrapingQuotaFetcher.swift  # Dashboard scraping (current)
│   │   ├── APIQuotaFetcher.swift       # API-based (PR #16513 — not yet live)
│   │   └── MockQuotaFetcher.swift      # Testing
│   ├── Services/
│   │   ├── DashboardScraper.swift     # SolidJS SSR parser
│   │   ├── CredentialStore.swift      # ~/.config/headroom/config.json
│   │   └── QuotaPollingService.swift   # Timer + state management
│   ├── UI/
│   │   ├── MenuBarView.swift          # Dropdown panel
│   │   ├── PreferencesView.swift      # Settings
│   │   └── PreferencesWindowController.swift  # Standalone NSWindow
│   └── Utilities/
│       └── DurationFormatter.swift     # Seconds → human readable
├── Tests/headroomTests/
│   ├── DashboardScraperTests.swift
│   ├── DurationFormatterTests.swift
│   ├── MockQuotaFetcherTests.swift
│   └── QuotaErrorTests.swift
├── bundle.sh                          # Build + sign .app
└── headroom.entitlements
```

## Data source

Scrapes the OpenCode Go dashboard at `https://opencode.ai/workspace/{id}/go` using the auth cookie. Parses SolidJS SSR hydration output:

```
rollingUsage:$R[123]={usagePercent:7,resetInSec:7920}
```

This is the same approach used by `slkiser/opencode-quota`, `pi-go-bars`, and `opencode-go-usage`.

The official API endpoint (`GET /zen/go/v1/usage`) is proposed in [PR #16513](https://github.com/anomalyco/opencode/pull/16513) but is not yet merged. The `APIQuotaFetcher` placeholder is ready once it ships.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Menu bar shows `ERR` | Auth cookie may be expired — get a fresh one from your browser. |
| Menu bar shows `?\|?\|?` | One or more quota windows not found in dashboard HTML. Open the OpenCode dashboard in a browser to verify. |
| Menu bar shows `--` | Not configured. Open Preferences and enter credentials. |
| "Load Saved" does nothing | No saved credentials found. Enter and Save first. |
| Dashboard format changed | Scraper regex patterns may need updating — file an issue. |
| All windows show 0% but dashboard disagrees | Auth cookie may be stale. Refresh from browser. |
| Can't interact with Preferences | Make sure you're running from the `.app` bundle, not a bare binary. Use `./bundle.sh && open build/headroom.app`. |

## FAQ

**Q: Why a config file instead of Keychain?**
Ad-hoc signed apps trigger intrusive Keychain permission dialogs that often render behind windows. File-based storage at `~/.config/headroom/` avoids this and matches the approach used by `slkiser/opencode-quota` and `pi-go-bars`.

**Q: Does it auto-launch at login?**
Not yet. You can add it manually: System Settings → General → Login Items → add `headroom.app`.

**Q: Can I use the API endpoint instead of scraping?**
Not yet. Track [PR #16513](https://github.com/anomalyco/opencode/pull/16513).

**Q: How do I quit if the menu bar button isn't responding?**
```bash
pkill -f headroom
```

## License

MIT

---

Built by [@PainInTheBhat](https://github.com/pain-in-the-bhat). Not affiliated with OpenCode.
