# headroom

macOS menu bar app for OpenCode Go quota. Glance at your menu bar, know exactly how much runway you have left.

```
7|2|18
```

Rolling (5h) | Weekly | Monthly — used %, lower is better. Matches the OpenCode dashboard.

## Features

- **Menu bar:** Colored `7|2|18` — each number independent (green/amber/red based on usage)
- **Dropdown panel:** Thin runway bars, reset timers, compact text-only actions
- **Auto-refresh:** 60s polling with exponential backoff on errors
- **Secure:** Credentials in `~/.config/headroom/config.json`, not plaintext Keychain prompts
- **Extensible:** Provider abstraction — scraping today, API when PR #16513 ships

## Requirements

- macOS 14 (Sonoma) or later
- An active [OpenCode Go](https://opencode.ai/docs/go/) subscription

## Setup

1. **Open Preferences** from the menu bar dropdown
2. **Workspace ID:** Visit `opencode.ai`, open your workspace → Go. Copy the ID from the URL: `https://opencode.ai/workspace/{id}/go`
3. **Auth Cookie:**
   - **Safari:** Preferences → Advanced → "Show Develop menu" → Develop → Show Web Inspector → Storage tab → Cookies → `opencode.ai` → copy the `auth` cookie value
   - **Chrome:** DevTools (F12) → Application → Storage → Cookies → `opencode.ai` → copy `auth`
4. **Click Save** — polling starts immediately

## Usage

- Menu bar shows used %: small numbers = calm, red numbers = act
- Hover for window labels (Rolling / Weekly / Monthly)
- Click for the detail panel with runway bars and reset timers
- **Refresh** forces an immediate fetch
- **Open Dashboard** opens opencode.ai in your browser

## Build

```bash
# Build and package as .app
./bundle.sh && open build/headroom.app

# Or open in Xcode
open Package.swift
# Then ⌘R to build and run
```

## Test

```bash
swift test
```

25 tests covering HTML scraping, mock data generation, duration formatting, and error types.

## Architecture

```
headroom/
├── Sources/
│   └── headroom/
│       ├── HeadroomApp.swift              # @main + StatusBarLabel
│       ├── Models/
│       │   ├── QuotaUsage.swift           # Core data types
│       │   └── QuotaWindowType.swift      # Window enums
│       ├── Providers/
│       │   ├── QuotaFetcher.swift          # Provider protocol
│       │   ├── ScrapingQuotaFetcher.swift  # Dashboard scraping (current)
│       │   ├── APIQuotaFetcher.swift       # API-based (future)
│       │   └── MockQuotaFetcher.swift      # Testing
│       ├── Services/
│       │   ├── DashboardScraper.swift     # SolidJS SSR parser
│       │   ├── CredentialStore.swift      # Config file storage (~/.config/headroom/)
│       │   └── QuotaPollingService.swift   # Timer + state
│       ├── UI/
│       │   ├── MenuBarView.swift          # Dropdown panel
│       │   ├── PreferencesView.swift      # Settings
│       │   └── PreferencesWindowController.swift  # Standalone NSWindow
│       └── Utilities/
│           └── DurationFormatter.swift     # Time formatting
├── Tests/
│   └── headroomTests/
│       ├── DashboardScraperTests.swift
│       ├── DurationFormatterTests.swift
│       ├── MockQuotaFetcherTests.swift
│       └── QuotaErrorTests.swift
├── bundle.sh                              # Build + sign .app
├── headroom.entitlements
└── TECHNICAL_DESIGN.md
```

### Data Source

Scrapes the OpenCode Go dashboard at `https://opencode.ai/workspace/{id}/go` using the auth cookie. Parses SolidJS SSR hydration output:

```
rollingUsage:$R[123]={usagePercent:7,resetInSec:7920}
```

Same approach used by `slkiser/opencode-quota`, `pi-go-bars`, and `opencode-go-usage`.

The official API endpoint (`GET /zen/go/v1/usage`) is proposed in [PR #16513](https://github.com/anomalyco/opencode/pull/16513). The `APIQuotaFetcher` placeholder is ready once it ships.

## FAQ

**Q: Is the auth cookie stored safely?**
A: Yes. macOS Keychain, not plaintext.

**Q: How often does it refresh?**
A: 60s default, configurable 15s–300s in Preferences.

**Q: What if the OpenCode dashboard changes?**
A: The scraper shows a clear error. Update regex patterns in `DashboardScraper.swift`, or switch to the API fetcher when available.

## License

MIT

---

Built by [@PainInTheBhat](https://github.com/pain-in-the-bhat)
