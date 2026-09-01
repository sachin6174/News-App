# News App 2.0

A small production-style iOS news reader that demonstrates UIKit and SwiftUI
working together, an offline-first Core Data cache, resilient REST networking,
accessibility, localisation, deep links, background refresh, tests, CI, and
TestFlight delivery.

The project intentionally has **zero third-party iOS runtime dependencies**. It
uses Apple frameworks so every important behavior is visible in this repository.

## First: rotate the exposed credential

An older version committed a real NewsAPI key. Deleting the line from Swift does
not make that key secret again because Git and public forks remember old commits.

1. Sign in to the NewsAPI account that owns the old key.
2. Revoke it immediately.
3. Create a replacement key.
4. Never paste the replacement into a tracked file.
5. If the repository is public, follow [SECURITY.md](SECURITY.md) to clean Git
   history after making a backup. Rotation is still mandatory even after cleanup.

The local Git `origin` also contained an embedded GitHub personal access token. It
has been replaced with a credential-free HTTPS URL, but that GitHub token must be
revoked because removing it locally cannot invalidate an already exposed token.

This repository now reads `NEWS_API_KEY` at runtime and contains only an empty
build-setting placeholder. `.gitignore` blocks `Secrets.xcconfig` and `.env`.

## Run the app

1. Open `News App.xcodeproj` in Xcode 16.4 or newer.
2. Select the **News App** scheme and an iOS 17+ simulator.
3. Open **Product → Scheme → Edit Scheme → Run → Arguments → Environment
   Variables**.
4. Add `NEWS_API_KEY` with the newly rotated key as its value.
5. Run with **⌘R**.

The environment variable is best for local development. Release automation writes
an untracked `Config/Secrets.xcconfig` only inside its temporary CI runner.
`Config/Secrets.xcconfig.example` documents the expected name without containing a
credential.

## How the app works, in plain language

Imagine a librarian with two shelves:

- The **internet shelf** has the newest stories but may be unavailable.
- The **Core Data shelf** contains the last stories the app successfully fetched.

At launch, `NewsListViewModel.start()` asks the Core Data shelf first. If cached
stories exist, the user sees them immediately with an **Offline copy** banner.
The app then asks the network for page one. A successful response replaces the old
ordinary-news snapshot and removes the banner. If the network fails, cached rows
stay visible. Bookmarks use separate rows, so refreshing the feed cannot erase a
saved story.

When the reader approaches the bottom, the ViewModel requests the next page.
Overlapping article URLs are de-duplicated while preserving server order. Pull to
refresh cancels old work and returns to page one.

## Architecture

The dependency direction is deliberately short:

```text
UIKit / SwiftUI views
        ↓
NewsListViewModel
        ↓
NewsRepository protocol
        ↓
DefaultNewsRepository
   ↙             ↘
NewsAPIService   DataStoreManager
(URLSession)     (Core Data)
```

- **UIKit:** `NewsListViewController` and `NewsArticleCell` build the feed with
  programmatic Auto Layout. No main storyboard or XIB controls the app UI.
- **SwiftUI integration:** `ArticleDetailView` is pushed through
  `UIHostingController` inside the UIKit navigation controller.
- **MVVM:** the controller renders state; `NewsListViewModel` owns pagination,
  search, cancellation, offline/error state, and bookmark decisions.
- **Repository:** `NewsRepository` hides where data comes from and makes tests use
  simple fakes.
- **REST/JSON:** `NewsAPIService` creates GET requests with `URLComponents`, adds
  the token header, uses async `URLSession`, validates HTTP codes, and decodes
  `Codable` models.
- **Core Data:** `DataStoreManager` performs every database operation on a private
  context and returns plain Swift values, never queue-bound managed objects.
- **Images:** `CachedImageLoader` checks `NSCache`, then a bounded disk cache, then
  URLSession. It rejects oversized files, downsamples publisher photos, and lets
  reused cells cancel old image tasks.

## Resilience behavior

The networking code retries only temporary failures: timeout, lost/no connection,
HTTP 408, 429, and 5xx. It waits 0.5 seconds and then 1 second. After two retries it
returns a real error state; it never spins forever. Decode errors and most 4xx
responses are not retried because repeating the same bad request cannot repair
them.

Swift Task cancellation is checked after network and image work. Pull-to-refresh,
screen teardown, and background-task expiration therefore stop requests and retry
sleeps instead of allowing stale results to overwrite newer state.

## Authentication

NewsAPI's API key is token-based authentication. The client sends it in the
`X-Api-Key` HTTP header rather than a query string. The token is injected through
`AppConfiguration`; it is not a global constant and is never logged. A missing key
fails before URLSession sends a request and produces a helpful configuration error.

Removing a key from Git is different from hiding it inside a shipped app: a skilled
person can inspect an iOS binary and recover a bundled provider key. A commercial
deployment should put the NewsAPI key on a backend, authenticate the app/user to
that backend with short-lived tokens, and let the backend call NewsAPI. This sample
fixes the public-source leak and demonstrates token injection, but does not claim
that an Info.plist value is a hardware-backed secret.

For an API requiring user accounts, the same boundary can be replaced with an
OAuth 2.0 token provider and Keychain storage without changing the ViewModel or UI.
This sample does not pretend NewsAPI supports an end-user OAuth login.

## Accessibility and localisation

- Every font uses a Dynamic Type text style and opts into content-size updates.
- Labels wrap instead of clipping at accessibility sizes.
- Bookmark controls have a 44-point minimum target, label, state-specific hint,
  and SF Symbol.
- Story images and headings expose meaningful VoiceOver information.
- Loading, refresh, error, and bookmark changes make VoiceOver announcements.
- The UI is localised in English and Hindi under `en.lproj` and `hi.lproj`.
- `testAccessibilityAudit()` runs Apple's automated XCUITest accessibility audit.

See [docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md) for the manual evidence matrix;
an automated audit helps, but it cannot replace a real VoiceOver walkthrough.

## Deep links and background refresh

A link shaped like the following opens the SwiftUI detail screen:

```text
newsapp://article?url=https%3A%2F%2Fexample.com%2Fstory
```

`DeepLinkRouter` accepts only the `newsapp`/`article` route and an HTTPS destination.
The scene delegate handles both cold and warm launches. `BGAppRefreshTask` asks iOS
for a future page-one refresh, updates the same Core Data cache, and cancels work if
the system's time expires. iOS intentionally decides the actual execution time.

## Tests

Run all shared-scheme tests with **⌘U**, or on macOS:

```bash
xcodebuild test \
  -project "News App.xcodeproj" \
  -scheme "News App" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro,OS=latest" \
  CODE_SIGNING_ALLOWED=NO \
  NEWS_API_KEY=local-test-placeholder
```

Coverage includes:

- unit tests for search, offline fallback, pagination, bookmarks, and deep links;
- a stubbed-URLSession integration test for auth headers, query parameters, JSON,
  HTTP handling, and bounded retry;
- an in-memory Core Data integration test for cache/bookmark persistence;
- deterministic XCUITest journeys for list/search/detail/bookmark, retry errors,
  deep links, and accessibility;
- `XCTApplicationLaunchMetric` and scrolling hitch measurements.

The `--ui-testing` launch argument swaps in local fixture data, so UI tests do not
depend on a changing headline, a real key, or internet availability.

## CI, profiling, and release

- `.github/workflows/ci.yml` runs tests, the Xcode static analyzer, a tracked-source credential scan,
  and uploads the `.xcresult` bundle as accessibility/performance evidence.
- [docs/INSTRUMENTS.md](docs/INSTRUMENTS.md) gives repeatable launch, scrolling,
  networking, allocations, and leak profiling steps plus a results table.
- `.github/workflows/testflight.yml` installs signing material on an ephemeral
  runner and calls `fastlane beta` to archive and upload to TestFlight.
- [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md) lists every required GitHub secret and
  the one-time App Store Connect setup.

This Windows checkout cannot run Xcode or Instruments. Therefore this repository
does **not** invent launch-time or memory numbers. Run the macOS workflow/profile,
store the `.xcresult`/`.trace` evidence, and record measured values before quoting
specific performance improvements on a résumé.

## Honest résumé bullets after validation

After CI passes on macOS and a TestFlight build is uploaded, these statements match
the implemented code:

> Built an offline-first iOS client using UIKit, SwiftUI, URLSession, Codable and
> Core Data, supporting REST API pagination, image caching, bounded retries,
> cancellation, and resilient loading, offline and error states.

> Added VoiceOver, Dynamic Type, English/Hindi localisation, deep links and
> background refresh; automated critical workflows with unit, integration and
> XCUITest coverage and added repeatable Instruments profiling for launch,
> scrolling, networking and memory.

Do not claim a production TestFlight release, passing CI percentage, or measured
performance number until the corresponding external run has actually completed.
