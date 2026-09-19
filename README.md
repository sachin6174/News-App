# News App 2.0

A small production-style iOS news reader that demonstrates UIKit and SwiftUI
working together, an offline-first Core Data cache, resilient REST networking,
accessibility, localisation, deep links, background refresh, tests, CI, and
TestFlight delivery.

The project intentionally has **zero third-party iOS runtime dependencies**. It
uses Apple frameworks so every important behavior is visible in this repository.

## Security cleanup status

An older version committed a real NewsAPI key. On 2 September 2026, both public
branches were rewritten with lease-protected force pushes to remove every
historical `News App/App/AppConstants.swift` blob. A post-rewrite scan found zero
credential-shaped values in either reachable branch history.

1. Sign in to the NewsAPI account that owns the old key.
2. Revoke it immediately.
3. Create a replacement key.
4. Never paste the replacement into a tracked file.
5. Ask any existing collaborator to make a fresh clone because old commit IDs no
   longer belong to the public branches.

History removal reduces rediscovery; it cannot invalidate a key somebody may
already have copied. Revocation is therefore still mandatory.

The local Git `origin` also contained an embedded GitHub personal access token. It
has been replaced with a credential-free HTTPS URL, but that GitHub token must be
revoked because removing it locally cannot invalidate an already exposed token.

This repository now reads `NEWS_API_KEY` at runtime and contains only an empty
build-setting placeholder. `.gitignore` blocks `Secrets.xcconfig` and `.env`.

## App Store review remediation (September 2026)

Submission `55302a14-e3c6-4fee-954e-8b1ec7096112` (build `2026091101`) was
rejected under **Guideline 4.2.2 — Design — Minimum Functionality**: reviewed
as "limited or no native functionality" beyond browsing headlines aggregated
from the internet. That verdict is about the user-facing experience, not the
code underneath it — the app already had an offline-first cache, background
refresh, and bookmarks, but nothing a reviewer could point to as native
functionality a web page could not offer.

In response, this branch adds:

- **Personalized topics ("For You")** — readers follow specific categories
  (Business, Technology, Sports, and more) from a new Topics screen; the main
  feed gets a topic bar to switch between followed topics and the general
  feed, each with its own offline snapshot.
- **Breaking-news alerts** — an opt-in local notification when a new top
  story appears, routed through the same deep-link path a shared link uses.
- **Listen to articles** — on-device text-to-speech playback of the headline
  and summary from the article screen.
- **A Home Screen widget** — source is written and ready under
  [`NewslyWidget/`](NewslyWidget); wiring it into a second Xcode target is a
  short manual step documented in [docs/WIDGET_SETUP.md](docs/WIDGET_SETUP.md).

See [docs/REQUIREMENTS_MATRIX.md](docs/REQUIREMENTS_MATRIX.md) for the same
"Implemented" vs. "Verified" honesty this project applies everywhere else —
these rows are marked **Implemented — not yet Mac-verified** until they are
actually built and exercised in Xcode. A draft reply for App Store Connect's
Resolution Center is at
[docs/APP_REVIEW_RESPONSE.md](docs/APP_REVIEW_RESPONSE.md).

## Run the app

1. Open `News App.xcodeproj` in Xcode 16.4 or newer.
2. Select the **News App** scheme and an iOS 17+ simulator.
3. Copy `.env.example` to `.env` and place the newly rotated development key
   after `NEWS_API_KEY=`. The real `.env` is ignored by Git.
4. From Terminal in the repository, run
   `./scripts/configure-local-env.sh`. It creates the ignored, owner-readable
   `Config/Secrets.xcconfig` without printing the key.
5. Run the Debug build with **⌘R**.

An environment variable still overrides the file and is useful in CI. Release
automation writes an untracked `Config/Secrets.xcconfig` only inside its temporary
runner. `Config/Secrets.xcconfig.example` documents the expected shape without
containing a credential.

Important: `.env` keeps a key out of Git; it does not make a key secret after it
is copied into an iOS application. Anyone can inspect an installed app bundle.
Use this direct NewsAPI key only for development. A production release must call
a backend that owns the provider key instead of embedding that provider key in
the app.

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

## Personalization, breaking-news alerts, and read-aloud

**Topics.** `Topic` is a small enum mirroring NewsAPI's own categories
(business, entertainment, health, science, sports, technology — `general` is
left out since the default "Top" feed already covers it). `TopicPreferencesStore`
persists which topics a reader follows in `UserDefaults`; `TopicArticleCache`
keeps a small offline JSON snapshot per topic. Both stay outside Core Data on
purpose, so the tested cache/bookmark schema in `DataStoreManager` never has
to change for this feature. `NewsListViewModel` keeps a topic's feed
(`topicArticles`/`topicState`) completely separate from the general feed's own
`allArticles`/`state`/pagination, so selecting a topic can never disturb the
general feed's tested behaviour.

**Breaking-news alerts.** `NotificationScheduler` wraps local (on-device)
`UNUserNotificationCenter` alerts — nothing here calls a push server.
`BreakingNewsNotifier` compares the newest page-one headline against the last
one the reader was told about (skipping the very first comparison, so
installing the app or turning alerts on never fires a notification for
whatever headline already happened to be on top) and asks
`NotificationScheduler` to post an alert only for a genuinely new story. This
runs from the one place both a foreground refresh and
`BackgroundRefreshManager` already share:
`DefaultNewsRepository.fetchHeadlines(page: 1, ...)`. Tapping a notification
reuses `DeepLinkRouter`'s existing, already-tested `newsapp://article?url=`
route — the same one a shared link uses. The feature defaults to off and only
requests permission when the reader turns it on from the Topics screen.

**Listen to articles.** `ArticleSpeechController` wraps `AVSpeechSynthesizer`
behind a small `ObservableObject` so `ArticleDetailView` can drive a
play/stop control with `@StateObject`. Playback stops automatically when the
detail screen disappears.

**Widget.** `WidgetDataWriter` (app target) mirrors the top few headlines
into an App Group–shared `UserDefaults` suite after every successful page-one
fetch and nudges `WidgetCenter` to refresh. It is written to no-op safely
before the App Group capability exists, so it shipped with the rest of this
change without requiring the widget extension target to exist yet. The
widget extension's own source lives under [`NewslyWidget/`](NewslyWidget);
see [docs/WIDGET_SETUP.md](docs/WIDGET_SETUP.md) to wire it into a second
Xcode target.

None of this was built or run from the environment that wrote it — only
written and reviewed as source. Build, run, and exercise it in Xcode before
relying on it, the same rule this project already applies to every claim in
[docs/REQUIREMENTS_MATRIX.md](docs/REQUIREMENTS_MATRIX.md).

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

The production branch was transferred to an Apple-silicon Mac and verified with
Xcode 26.6 on an iPhone 17 Pro simulator running iOS 26.5. All 17 unit,
integration, UI, accessibility, and performance tests passed; static analysis and
a Release simulator build also passed. Instruments Time Profiler/Network trace
manifests, XCTest metrics, a leak report, environment details, and a running-app
screenshot are committed under [docs/evidence](docs/evidence). See the exact,
non-inflated results in [docs/evidence/VERIFICATION.md](docs/evidence/VERIFICATION.md).

GitHub-hosted Actions are currently blocked before the workflow starts. GitHub's
[latest run](https://github.com/sachin6174/News-App/actions/runs/33573349155)
states: “The job was not started because your account is locked due to a billing
issue.” That is an account condition, not an app test failure. A real TestFlight
upload also still requires the private signing and App Store Connect secrets
listed in [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md).

## Honest résumé bullets after Mac validation

These statements now match both the implemented code and the saved Mac evidence:

> Built an offline-first iOS client using UIKit, SwiftUI, URLSession, Codable and
> Core Data, supporting REST API pagination, image caching, bounded retries,
> cancellation, and resilient loading, offline and error states.

> Added VoiceOver, Dynamic Type, English/Hindi localisation, deep links and
> background refresh; automated critical workflows with unit, integration and
> XCUITest coverage and added repeatable Instruments profiling for launch,
> scrolling, networking and memory.

Do not claim a production TestFlight release or passing GitHub Actions percentage
until those external account-dependent runs actually complete.
