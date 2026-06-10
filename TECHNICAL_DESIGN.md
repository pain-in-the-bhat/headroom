# OpenCode Usage — macOS Menu Bar App

## Technical Design Document

### 1. Overview

A native macOS menu bar application (MenuBarExtra) that displays OpenCode Go subscription quota usage — rolling (5-hour), weekly, and monthly usage windows with remaining percentages and reset timers.

### 2. Research Findings

#### 2.1 Official API Status

| Source | Status | Details |
|--------|--------|---------|
| PR #16513 (`/zen/go/v1/usage`) | Open, not merged | Proposed endpoint at `GET /zen/go/v1/usage`. Copies pattern from `/zen/v1/models` and logic from `/workspace/[id]/billing/lite-section.tsx`. Not yet deployed. |
| Issue #16017 | Open | Feature request for Go plan usage API. Proposes response format with `windows.{rolling,weekly,monthly}.{usage_percent,resets_in_seconds}`. |
| Current state | No public REST API | All third-party tools (slkiser/opencode-quota, pi-go-bars, opencode-go-usage) use dashboard HTML scraping. |

#### 2.2 Dashboard Scraping Approach

- **URL:** `https://opencode.ai/workspace/{workspaceId}/go`
- **Auth:** `auth` cookie from browser DevTools on `opencode.ai`
- **Method:** Parse SolidJS SSR hydration output embedded in the HTML
- **Target data:** Objects of form `rollingUsage:$R[N]={usagePercent:42,resetInSec:3600}` (and similarly for `weeklyUsage`, `monthlyUsage`)
- **Regex pattern (TypeScript):** `/rollingUsage:\$R\[\d+\]=\{[^}]*usagePercent:(\d+)[^}]*resetInSec:(\d+)[^}]*\}/`
- **Proven in production:** slkiser/opencode-quota plugin (1k+ stars) uses this approach

#### 2.3 Quota Windows

| Window | Dollar limit | Duration | Data field |
|--------|-------------|----------|------------|
| Rolling | $12 | 5 hours | `rollingUsage` |
| Weekly | $30 | 7 days | `weeklyUsage` |
| Monthly | $60 | 30 days | `monthlyUsage` |

### 3. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    QuotaPollingService                    │
│  ┌─────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │  Timer (60s) │  │  QuotaFetcher  │  │  @Published  │  │
│  │              │  │  (protocol)    │  │  state       │  │
│  └─────────────┘  └───────┬────────┘  └──────────────┘  │
└───────────────────────────┼──────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐  ┌────────────────┐  ┌──────────────────┐
│MockFetcher   │  │ScrapingFetcher │  │APIFetcher        │
│(dev/testing) │  │(current)       │  │(future, when     │
│              │  │                │  │ PR #16513 ships) │
└──────────────┘  └───────┬────────┘  └──────────────────┘
                          │
                          ▼
                 ┌────────────────┐
                 │DashboardScraper│
                 │(URLSession +  │
                 │ regex parsing)│
                 └───────┬────────┘
                         │
                         ▼
                 ┌────────────────┐
                 │KeychainService │
                 │(Security.fw)   │
                 └────────────────┘

┌─────────────────────────────────────────────────────────┐
│                        UI Layer                          │
│  ┌──────────────────────┐  ┌──────────────────────────┐ │
│  │   MenuBarExtra       │  │   PreferencesView        │ │
│  │   "OC 62|41|18"      │  │   - Workspace ID field   │ │
│  │   (status bar text)  │  │   - Auth cookie field    │ │
│  │                      │  │   - Refresh interval     │ │
│  │   Dropdown:          │  │   - Test Connection btn  │ │
│  │   - Rolling: 62%     │  │                          │ │
│  │   - Weekly: 41%      │  │                          │ │
│  │   - Monthly: 18%     │  │                          │ │
│  │   - Last updated     │  │                          │ │
│  │   - Refresh btn      │  │                          │ │
│  │   - Open Dashboard   │  │                          │ │
│  │   - Settings...      │  │                          │ │
│  │   - Quit             │  │                          │ │
│  └──────────────────────┘  └──────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

#### 3.1 Component Separation

| Component | Responsibility |
|-----------|---------------|
| **Models** | `QuotaUsage`, `QuotaWindow` — pure data types, Codable |
| **Providers** | `QuotaFetcher` protocol + implementations (Mock, Scraping, API) |
| **Services** | `DashboardScraper` (HTML→data), `KeychainController` (credential storage), `QuotaPollingService` (timer + state management) |
| **UI** | `MenuBarView` (MenuBarExtra + dropdown), `PreferencesView` (settings sheet) |
| **Utilities** | `DurationFormatter` (seconds→human readable) |

### 4. API Design

#### 4.1 QuotaFetcher Protocol

```swift
protocol QuotaFetcher {
    func fetch() async throws -> QuotaUsage
}
```

#### 4.2 QuotaUsage Model

```swift
struct QuotaUsage: Codable, Equatable {
    let rolling: QuotaWindow?
    let weekly: QuotaWindow?
    let monthly: QuotaWindow?
    let lastUpdated: Date
}

struct QuotaWindow: Codable, Equatable {
    let usagePercent: Double      // 0–100
    let resetInSeconds: TimeInterval
    var remainingPercent: Double { 100 - usagePercent }
}
```

### 5. Future API Adaptation

When PR #16513 is merged and the `/zen/go/v1/usage` endpoint becomes available:

1. **Create `APIQuotaFetcher`** implementing `QuotaFetcher` protocol
   - Endpoint: `GET https://opencode.ai/zen/go/v1/usage`
   - Auth: `Bearer <api-key>` header
   - Expected Response: `{ "rolling": { "usagePercent": 42, "resetInSeconds": 3600 }, ... }`
2. **Add Auto-detection**: Try API fetcher first; fall back to scraper if it fails
3. No UI changes needed — the provider abstraction isolates the data source change

### 6. Credential Storage

- **Framework:** macOS Keychain via `Security.framework` (SecItemAdd/SecItemCopyMatching)
- **Stored values:**
  - `workspaceId` — OpenCode workspace ID
  - `authCookie` — auth cookie from browser
  - `apiKey` — OpenCode API key (for future API-based auth)
- **Access control:** App-specific, user must authorize first access
- **Alternatives considered and rejected:**
  - UserDefaults (insecure — plaintext on disk)
  - File-based `.env` or config file (not native, no access control)

### 7. Refresh Strategy

| Aspect | Value |
|--------|-------|
| Poll interval | 60 seconds (configurable in Preferences) |
| Error backoff | On failure, retry after 30s, then 2m, 5m, cap at 15m |
| Stale indicator | Show "⚠️" prefix or dimmed text when data > 5 minutes old |
| Manual refresh | Menu item "Refresh" forces immediate fetch |

### 8. Assumptions

1. **Dashboard HTML structure is stable.** The SolidJS SSR hydration output format (`rollingUsage:$R[N]={...}`) has been stable across multiple opencode-quota plugin releases since April 2026. If it changes, the regex patterns in `DashboardScraper.swift` need updating.
2. **`auth` cookie does not expire frequently.** Based on community reports, the cookie lasts for multiple days/weeks.
3. **macOS 14+ (Sonoma)** is the minimum deployment target for `MenuBarExtra` API.
4. **The user has an active OpenCode Go subscription** and has access to their workspace ID and auth cookie.

### 9. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Dashboard HTML changes | Scraper breaks | Regex-based parsing with testable patterns; provider abstraction allows swapping to API; user gets clear error message |
| Auth cookie expires | No data | Show "Auth required" in menu; provide easy re-auth flow in Preferences |
| API endpoint ships | Scraping becomes obsolete | Provider abstraction; add `APIQuotaFetcher` implementation; auto-detect working source |
| Rate limiting | Data doesn't update | 60s polling interval is conservative; implement exponential backoff on failure |
| Keyboard Maestro/GitHub Copilot PR already solved this | Reinventing wheel | The existing solutions are TUI plugins for OpenCode itself or VS Code extensions. This is the first native macOS menu bar implementation. |

### 10. Development Plan

1. ✅ Research data sources
2. ✅ Technical design document
3. Implement models and provider protocol
4. Implement DashboardScraper (HTML parsing)
5. Implement Keychain storage
6. Implement MockQuotaFetcher
7. Implement ScrapingQuotaFetcher
8. Implement QuotaPollingService
9. Implement MenuBarView (SwiftUI MenuBarExtra)
10. Implement PreferencesView
11. Wire up App entry point
12. Write unit tests
13. Build and test

### 11. Configuration File

For users who prefer file-based config over Keychain:

**Location:** `~/.config/opencode-usage/config.json`
```json
{
  "workspaceId": "wrk_xxx",
  "authCookie": "xxx",
  "refreshInterval": 60,
  "fetcher": "scraping"
}
```

### 12. Open Questions

1. Does the `/zen/go/v1/usage` endpoint require a specific auth mechanism (session cookie vs API key)?
2. What's the exact response format of the endpoint once deployed?
3. Should we support multiple workspaces?
4. Should we add notification when quota exceeds threshold?

---

*Last updated: June 2026*
*Author: PainInTheBhat*
