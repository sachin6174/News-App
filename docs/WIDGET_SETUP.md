# Adding the Home Screen widget

The Swift source for a "Top Headlines" widget already exists under
[`NewslyWidget/`](../NewslyWidget) at the repository root. It is **not** wired
into the Xcode project yet, on purpose: a widget lives in its own app
extension target (its own bundle ID, its own Info.plist, an App Group shared
with the main app), and only Xcode's own target wizard can create that safely.
Hand-editing `project.pbxproj` to fabricate a second target is exactly the
kind of change that is easy to get subtly wrong in a way Xcode (rather than a
compiler) is needed to catch, so this is a short manual step instead.

None of this blocks resubmitting the app without the widget — it is an
additional, optional signal for a future submission. The app target already
writes to the shared App Group container (`WidgetDataWriter`) and safely
no-ops until the steps below are done, so nothing needs to be reverted if you
skip this for now.

## 1. Create the widget extension target

1. In Xcode, **File → New → Target…**.
2. Choose **Widget Extension**, click Next.
3. Product Name: `NewslyWidget`. Uncheck "Include Configuration Intent" (this
   widget uses a plain `StaticConfiguration`, not a user-configurable one).
   Uncheck "Include Live Activity" too — not used here.
4. Team/Bundle Identifier: let Xcode suggest
   `in.sachinserver.News-App.NewslyWidget`. Finish, and say **Activate** when
   it offers to activate the new scheme.

Xcode creates a `NewslyWidget/` group with its own boilerplate Swift files
(typically `NewslyWidget.swift`, `NewslyWidgetBundle.swift` or similar) and a
matching `NewslyWidgetExtension` target using a synchronized folder, the same
mechanism this project's main app/test targets already use.

## 2. Replace the generated source with the files in this repo

1. Delete the boilerplate `.swift` files Xcode just generated inside the new
   target's folder (keep the folder itself, and keep its auto-generated
   `Assets.xcassets`/Info if present).
2. Copy in the four files from [`NewslyWidget/`](../NewslyWidget) at the repo
   root: `NewslyWidgetEntry.swift`, `NewslyWidgetProvider.swift`,
   `NewslyWidgetEntryView.swift`, `NewslyWidget.swift`. Drag them into the new
   target's folder in Xcode (checking **NewslyWidget** as the target
   membership, main app target unchecked), or paste their contents into new
   files created in place — either way, confirm in the File Inspector that
   each file's Target Membership is the widget extension only.
3. Set the widget target's **iOS Deployment Target** to 17.0, matching the
   main app (Project settings → NewslyWidget target → General).

## 3. Share data between the app and the widget with an App Group

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

## 4. Build, run, and add the widget

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
- As with the rest of this project, this has not been built or run in Xcode
  from this environment — only written and reviewed as source. Treat it as
  **implemented, not yet Mac-verified**, the same status the rest of this
  round's changes carry in `docs/REQUIREMENTS_MATRIX.md` until you build it.
