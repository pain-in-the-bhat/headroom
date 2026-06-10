# headroom

A native macOS menu bar app that shows OpenCode Go quota at a glance. How much room you have left before rate limits hit.

```
OC 62|41|18
```

Rolling (5h) | Weekly | Monthly — remaining percentages, updated every 60 seconds.

## Features

- **Menu bar display:** Compact `OC 62|41|18` showing remaining quota for all three windows
- **Detailed dropdown:** Progress bars, reset timers, and status indicators
- **Auto-refresh:** Polls every 60 seconds with exponential backoff on errors
- **Secure storage:** Credentials stored in macOS Keychain
- **Error handling:** Clear auth errors, network failures, and stale data indicators
- **Extensible:** Provider abstraction allows swapping between scraping and API (future)

## Requirements

- macOS 14 (Sonoma) or later
- An active [OpenCode Go](https://opencode.ai/docs/go/) subscription

## Setup

1. **Open Preferences** from the menu bar dropdown (or launch the app)
2. **Enter your Workspace ID:**
   - Visit `https://opencode.ai/workspace/` in your browser
   - Navigate to your Go workspace
   - Copy the workspace ID from the URL: `https://opencode.ai/workspace/{workspaceId}/go`
3. **Enter your Auth Cookie:**
   - Open browser DevTools (F12) on `opencode.ai`
   - Go to Application → Storage → Cookies
   - Find the `auth` cookie and copy its value
4. **Click Save** — the app will immediately start polling

## Usage

- The menu bar shows `OC 62|41|18` — remaining percentage for Rolling, Weekly, Monthly
- Click to open the dropdown with detailed progress bars and reset timers
- Use **Refresh** to force an immediate update
- Use **Open Dashboard** to open opencode.ai in your browser
- Use **Preferences** to update credentials or change settings

## Architecture

```
headroom/
├── Sources/
│   └── headroom/
│       ├── HeadroomApp.swift             # @main entry point + StatusBarLabel
│       ├── Models/
│       │   ├── QuotaUsage.swift        # Core data models
│       │   └── QuotaWindowType.swift   # Window type enums
│       ├── Providers/
│       │   ├── QuotaFetcher.swift       # Provider protocol + credentials
│       │   ├── MockQuotaFetcher.swift   # Mock data for testing
│       │   ├── ScrapingQuotaFetcher.swift  # Dashboard scraping
│       │   └── APIQuotaFetcher.swift   # Future API-based fetcher
│       ├── Services/
│       │   ├── DashboardScraper.swift  # HTML parsing logic
│       │   ├── KeychainController.swift # Secure credential storage
│       │   └── QuotaPollingService.swift # Timer + state management
│       ├── UI/
│       │   ├── MenuBarView.swift       # Menu bar dropdown
│       │   └── PreferencesView.swift   # Settings screen
│       └── Utilities/
│           └── DurationFormatter.swift  # Time formatting
├── Tests/
│   └── headroomTests/
│       ├── DashboardScraperTests.swift
│       ├── MockQuotaFetcherTests.swift
│       ├── DurationFormatterTests.swift
│       └── QuotaErrorTests.swift
└── TECHNICAL_DESIGN.md
```

### Data Source

The app currently scrapes the OpenCode Go dashboard at `https://opencode.ai/workspace/{id}/go` using the auth cookie. This is the same approach used by all existing third-party tools (slkiser/opencode-quota, pi-go-bars, opencode-go-usage).

The dashboard is a SolidJS application with SSR. Quota data is embedded in the HTML as hydration output:

```
rollingUsage:$R[123]={usagePercent:42,resetInSec:7920}
```

An official API endpoint at `GET /zen/go/v1/usage` has been proposed in [PR #16513](https://github.com/anomalyco/opencode/pull/16513) but is not yet available. The `APIQuotaFetcher` placeholder is ready to be wired once it ships.

### Fetch Strategies

| Strategy | Description | Status |
|----------|-------------|--------|
| `scraping` | Dashboard HTML scraping | ✅ Current default |
| `auto` | Try API first, fall back to scraping | ⏳ Same as scraping for now |
| `api` | Official API endpoint | 🔜 Ready for PR #16513 |
| `mock` | Simulated data for testing | ✅ Available in Preferences |

## Development

### Build

```bash
swift build
```

### Test

```bash
swift test
```

25 unit tests covering:
- HTML parsing with multiple field orderings
- Mock data generation and value ranges
- Duration formatting
- Error types and fetch results

### Run

```bash
swift run
```

Or open in Xcode and run from there.

## FAQ

**Q: Is the auth cookie secure?**
A: Yes. Credentials are stored in the macOS Keychain, not in plain text on disk.

**Q: How often does it refresh?**
A: Every 60 seconds by default, configurable in Preferences (15s–300s).

**Q: What happens if the dashboard changes?**
A: The scraper will fail with a clear error message. Update the regex patterns in `DashboardScraper.swift` or switch to the API fetcher once available.

**Q: Can I use the API endpoint instead?**
A: Not yet. The `/zen/go/v1/usage` endpoint is proposed in PR #16513 but not merged. Track that PR for updates.

## License

MIT

---

Built by [@PainInTheBhat](https://github.com/pain-in-the-bhat)
