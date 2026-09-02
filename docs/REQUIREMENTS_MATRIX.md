# News App 2.0 strict acceptance matrix

This table maps every requested résumé requirement to source code and evidence.
“Implemented” means the feature exists in the application. “Verified” additionally
means an automated test, Mac build, saved measurement, or live smoke test exercised
it. External account operations are listed separately so the repository never
pretends that a workflow file equals an App Store delivery.

| Requirement | Status | Implementation and proof |
|---|---|---|
| Swift + UIKit + SwiftUI | Verified | UIKit feed in `NewsListViewController`; SwiftUI detail in `ArticleDetailView`; integration through `UIHostingController`; 17-test Mac run passed. |
| Programmatic Auto Layout | Verified | `NewsListViewController` and `NewsArticleCell` create constraints in code; the main storyboard was removed; UI tests passed. |
| REST, URLSession, JSON, Codable | Verified | `NewsAPIService` builds GET requests with `URLComponents`, uses async `URLSession`, validates HTTP responses, and decodes `Codable` models; stubbed integration tests passed. |
| Pagination | Verified | `NewsListViewModel` requests the next page near the final rows, de-duplicates article URLs, and stops at `totalResults`; unit and scrolling tests passed. |
| Retry and backoff | Verified | Temporary connection errors, 408, 429, and 5xx responses retry at bounded 0.5 s / 1 s delays; integration tests verify the bound. |
| Cancellation | Verified | Refresh, navigation teardown, reused cells, background expiration, URLSession, and retry sleeps cooperate with Swift task cancellation; integration tests passed. |
| Loading, empty, offline, and error states | Verified | The ViewModel exposes explicit states; deterministic XCUITests cover content and retry UI; offline fallback is unit-tested. |
| Offline-first Core Data | Verified | Cached headlines render before refresh and bookmarks persist separately on private contexts; in-memory Core Data integration tests passed. |
| Image caching | Verified | `CachedImageLoader` uses memory plus bounded disk caches, downsampling, size validation, and cell-task cancellation with no third-party dependency. |
| Token authentication | Verified | A rotated token is injected from ignored local/CI configuration and sent in the `X-Api-Key` header, never the URL; the integration test asserts the header. |
| Dynamic Type | Verified | Semantic fonts, content-size adjustment, wrapping labels, and flexible constraints are implemented; Apple's accessibility audit passed. |
| VoiceOver | Verified | Labels, hints, traits, state descriptions, meaningful image text, 44-point controls, and announcements are implemented; automated audit passed. |
| Localization | Verified | English and Hindi string resources cover the application interface and state/error messages. |
| Unit tests | Verified | Search, pagination, offline fallback, bookmarks, and deep-link parsing are covered in the shared scheme. |
| Integration tests | Verified | Stubbed URLSession and in-memory Core Data tests cover real subsystem boundaries. |
| XCUITest | Verified | Search/detail/bookmark, deterministic error/retry, deep link, accessibility audit, launch, and scrolling workflows execute real UI. |
| Instruments: launch | Verified | Time Profiler manifest and five `XCTApplicationLaunchMetric` samples are saved under `docs/evidence`. |
| Instruments: scrolling | Verified | Time Profiler manifest and five scrolling/deceleration signpost samples are saved under `docs/evidence`. |
| Instruments: networking | Verified | Network trace manifest contains CFNetwork task and transaction schemas; the live-key smoke test loaded current publisher content and images. |
| Instruments: memory | Verified with simulator limitation | Apple `leaks`/`vmmap` evidence reports 21.9 MiB footprint, 22.8 MiB peak, and zero reported leaked bytes; the readable-memory simulator limitation is documented. |
| GitHub Actions | Implemented; externally blocked | CI defines source/secret audit, full tests, static analysis, and xcresult upload. GitHub currently blocks jobs before checkout because the account is locked for billing. |
| TestFlight delivery | Implemented; credentials required | A tag/manual workflow installs signing assets, validates the API setting, archives via Fastlane, uploads with an App Store Connect API key, and cleans temporary secrets. No upload is claimed without private Apple credentials. |
| Deep links | Verified | `newsapp://article?url=...` validates an HTTPS destination and routes cold/warm launches into the SwiftUI detail screen; unit and XCUITests passed. |
| Background refresh | Implemented | `BGAppRefreshTask` refreshes page one into the same Core Data cache and cancels when iOS expires the task. Scheduling time remains controlled by iOS. |
| Remove SDWebImage mismatch | Verified | No package, pod, framework, import, or binary dependency remains; the app uses `CachedImageLoader` and accurately declares zero third-party runtime dependencies. |
| Remove committed API key | Current tree verified; history cleanup required | Current tracked files contain no live key and `.env`/`Secrets.xcconfig` are ignored. The old `AppConstants.swift` blob remains in public Git history until the authorized history rewrite and remote force-push complete. |

## Saved verification

See `docs/evidence/VERIFICATION.md` for the machine, Xcode, simulator, exact test
counts, raw metrics, trace manifests, memory reports, Release build, and live API
screenshot. The résumé bullets in `README.md` are limited to claims supported by
that evidence.
