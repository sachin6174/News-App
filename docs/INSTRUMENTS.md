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

## Results record

Fill this table only from saved evidence:

| Commit / device | Cold launch median / p95 | Warm launch median / p95 | Scroll hitches | Peak memory | Leaks | Trace link |
|---|---:|---:|---:|---:|---:|---|
| Not measured in this Windows environment | — | — | — | — | — | Run on macOS/device |

If a code change is made after profiling, repeat the same scenarios. Old trace
numbers are not evidence for a different binary.
