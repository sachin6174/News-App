# The Home Screen widget

The "Top Headlines" widget lives under [`NewslyWidget/`](../NewslyWidget) at
the repository root and **is wired into the Xcode project** as an app
extension target (`NewslyWidget`, bundle ID
`in.sachinserver.News-App.NewslyWidget`), embedded into the app bundle's
`PlugIns/` directory.

For a long time the source existed but belonged to no target, so the widget
never actually shipped despite being documented here. That is fixed:
[`scripts/add-widget-target.rb`](../scripts/add-widget-target.rb) adds the
target via the `xcodeproj` gem, and the result is build-verified — Debug and
Release both succeed and `NewslyWidget.appex` is present inside `News App.app`
with the correct bundle identifier and the
`com.apple.widgetkit-extension` extension point.

The script is idempotent: it exits early if the target already exists, so
re-running it after a fresh clone is harmless.

## Remaining step: the App Group

One piece is deliberately **not** wired up yet. The app and the widget share
data through an App Group, and entitlements referencing a group identifier
that is not registered on the Apple Developer portal will break code signing
for the main app's archive. So the entitlements are not attached to either
target until the identifier exists on the portal.

Until then the widget builds, installs, and renders — it just shows its
"Open Newsly to load today's headlines" placeholder, because
`UserDefaults(suiteName:)` returns nil without the entitlement and both
`WidgetDataWriter` and `NewslyWidgetProvider` no-op safely in that case.

To finish it:

The widget can't see the app's Core Data store directly — extensions run as
separate processes. Instead the app writes a small JSON snapshot of the top
headlines to a shared `UserDefaults` suite (an App Group), and the widget
reads it. `WidgetDataWriter.swift` (main app target) and
`NewslyWidgetProvider.swift` (widget target) already agree on the identifier
`group.in.sachinserver.News-App` — you only need to register it:

1. Select the **News App** target → **Signing & Capabilities** → **+
   Capability** → **App Groups**.
2. Click **+** under App Groups and add `group.in.sachinserver.News-App`
   exactly as written (Xcode may propose its own suggested string first —
   type over it).
3. Repeat for the **NewslyWidget** target: **Signing & Capabilities** → **+
   Capability** → **App Groups** → check the same
   `group.in.sachinserver.News-App` group (it will now appear in the list
   since the app target already registered it).
4. If your account/team cannot use that exact identifier for any reason and
   Xcode assigns a different one, update the `appGroupIdentifier` constant in
   **both** `News App/Models/Services/WidgetDataWriter.swift` and
   `NewslyWidget/NewslyWidgetProvider.swift` to match it exactly.

Ready-made entitlements files are already in the repo for both targets
(`NewslyWidget/NewslyWidget.entitlements` and
`News App/App/Resources/News App.entitlements`), so once the group exists on
the portal you can point `CODE_SIGN_ENTITLEMENTS` at them instead of adding
the capability by hand.

## Build, run, and add the widget

1. Select the **News App** scheme (not the widget scheme) and run on a
   simulator or device once, so the app fetches headlines at least once and
   `WidgetDataWriter` writes the shared snapshot.
2. Long-press the Home Screen → tap **+** → search "Newsly" → add the small
   or medium **Top Headlines** widget.
3. It should show the real top headline (not the "Open Newsly to load
   today's headlines" placeholder). If it still shows the placeholder, re-open
   the app to force a fresh fetch, then remove and re-add the widget, or wait
   a few minutes for WidgetKit's own refresh budget.
4. Tapping the widget should open the app directly on that story, using the
   same `newsapp://article?url=` deep link the app already validates — no
   extra code was needed on the app side for this to work.

## Notes

- This MVP widget uses a plain, non-configurable `StaticConfiguration`. A
  natural next step is an `AppIntentConfiguration` letting the person pick
  which followed topic the widget shows.
- The widget's own timeline refreshes roughly every 45 minutes as a fallback,
  but in practice it updates sooner because the app calls
  `WidgetCenter.shared.reloadAllTimelines()` right after every successful
  page-one fetch (foreground or background).
- The target itself is **Mac-verified**: built on macOS 26.6.2 / Xcode 26.6 in
  both Debug and Release, with the embedded `.appex` inspected to confirm its
  bundle identifier and extension point. What is *not* yet verified is the
  widget rendering real data on a Home Screen, since that needs the App Group
  above.
