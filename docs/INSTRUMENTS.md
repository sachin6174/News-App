# Instruments performance runbook

Performance claims need measurements from a release build on consistent hardware.
Do not compare a Debug simulator run with a Release physical-device run.

## Test setup

1. Choose one physical iPhone, record its model, iOS version, battery state, Xcode
   version, app commit, network type, and whether Low Power Mode is enabled.
2. In Xcode select **Product → Profile**. The shared scheme uses Release for Profile.
3. Delete and reinstall before a cold-launch sample. Keep the installed cache for a
   warm/offline sample.
4. Run each scenario at least five times. Report median and p95, not the best run.
5. Save `.trace` files outside DerivedData and attach them to the release/CI artifact.

## Launch

Use the **App Launch** template. Measure from process start until the first story
list becomes responsive. Record cold-online, warm-online, and cached-offline cases.
Investigate main-thread work, synchronous disk I/O, and any frame where UIKit cannot
respond. The committed `XCTApplicationLaunchMetric` provides a repeatable regression
signal; Instruments explains where the time went.

## Scrolling

Use **Animation Hitches** with a populated fixture or stable captured response.
Scroll rapidly from the first row through page two and back. Look for long hitches,
image decoding on the main thread, repeated cell layout, and unexpected network
work. `NewsPerformanceUITests.testScrollingPerformance` records the automated hitch
metric while Instruments supplies a detailed timeline.

## Networking

Use the **Network** instrument. Pull to refresh, load page two, cancel a refresh,
and simulate an offline connection. Confirm:

- the token appears in neither URL nor console output;
- page and pageSize are present;
- temporary failures stop after the configured retry bound;
- cancellation ends the task;
- image requests fall after the memory/disk cache warms.

Redact authorization/header values before sharing a trace.

## Memory and leaks

Use **Allocations** and **Leaks**. Open and close the SwiftUI detail screen at least
20 times, scroll through two pages, search, and switch segments. Mark the heap before
and after. `NewsListViewController`, hosting controllers, cells, URLSession tasks,
and decoded images should return to a stable plateau. A cache may retain bounded
images by design; continuous unbounded growth is not acceptable.

## Verified simulator result

The saved Instruments trace manifests were captured at rewritten commit
`0c20f68a6edc489f99c897c1996485cb314eb594`; the complete XCTest metric suite was
repeated on the unchanged application code at verified source commit
`a54dbef7a5f647bdc7f337632fe467792b3987ad`. Both used Xcode 26.6 on an
Apple-silicon Mac and an iPhone 17 Pro simulator running iOS 26.5. Xcode 26.6
does not support the Network Connections or Animation
Hitches instruments when directly targeting this simulator, so the repeatable
script records the simulator's host processes with Time Profiler and Network.
The app's own XCTest signpost metric supplies the scrolling regression number.

| Evidence | Result |
|---|---|
| Full test suite | 17 passed, 0 failed, 0 skipped |
| Repeat launch duration | Median 1.555 s; five samples; maximum 2.127 s |
| Scroll drag/deceleration duration | Median 2.567 s across five measured gestures; this is duration, not a hitch count |
| Memory footprint | 21.9 MiB captured; 22.8 MiB peak |
| Leak scan | 0 leaks / 0 bytes reported; simulator security limited the scan to readable memory |
| Static analyzer | Passed |
| Release simulator build | Passed; app bundle 1,478,656 bytes |

The small review artifacts are in [evidence](evidence), including the
[launch trace manifest](evidence/Launch-toc.xml),
[scrolling trace manifest](evidence/Scrolling-toc.xml),
[network trace manifest](evidence/Networking-toc.xml), and
[raw XCTest performance metrics](evidence/FullPerformanceMetrics.json). The
large binary `.trace` packages remain in the temporary Mac verification checkout
instead of bloating Git.

Run `scripts/collect-mac-instruments-evidence.sh` from the Mac checkout to repeat
the simulator capture. A physical-device pass is still recommended before making
claims about real-user cold launch, thermal behavior, radio networking, or memory.

If a code change is made after profiling, repeat the same scenarios. Old trace
numbers are not evidence for a different binary.
