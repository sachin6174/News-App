# Reply for App Store Connect (Guideline 4.2.2)

For the Resolution Center thread on submission
`55302a14-e3c6-4fee-954e-8b1ec7096112`, app ID `6810530638`.

Unlike the earlier draft, every feature named below has been built and run on a
Mac against the production backend: Debug and Release both build, the full test
suite passes (16 tests), and the app was launched on an iPhone 17 Pro Max
simulator showing live headlines. The mention of a Home Screen widget has been
removed — the widget is **not** in this build, and promising a feature the
reviewer cannot find is its own rejection.

---

Hello,

Thank you for the feedback on submission
55302a14-e3c6-4fee-954e-8b1ec7096112 (Guideline 4.2.2 — Minimum
Functionality). We understand the concern: the reviewed build presented
aggregated headlines with little functionality beyond a web feed.

This build (version 1.0, build 1) adds native functionality on top of the
article feed:

1. **Personalized topics.** Readers choose the topics they want to follow —
   Business, Technology, Sports, Health, Science, Entertainment — from a Topics
   screen. The main feed carries a topic bar for switching between followed
   topics and the general feed, and each topic keeps its own offline copy so
   that feed stays readable without a connection.

2. **Breaking-news alerts.** With the reader's explicit opt-in permission, the
   app posts a local notification when a new top story appears. Tapping it opens
   that specific story inside the app.

3. **Listen to articles.** Every article screen has a Listen control that reads
   the headline and summary aloud using on-device speech synthesis, for
   hands-free and more accessible reading.

Alongside these, the app keeps bookmarked stories on device for offline reading,
supports search across loaded headlines, and ships full VoiceOver and Dynamic
Type support with English and Hindi localization.

These are implemented natively with Apple frameworks — UserNotifications for
alerts, AVSpeechSynthesizer for speech, Core Data for offline storage — and the
app has no third-party runtime dependencies.

One change worth noting for your review: the app no longer carries a news
provider credential in its binary. It now calls a purpose-built endpoint on our
own server, which holds that credential.

Please let us know if there is anything further you would like us to address.

Thank you,
Sachin Kumar

---

### Check before sending

- [x] Features verified on a Mac, not just written — topics bar, notification
      scheduling and speech controls are all present in build 1.
- [x] Version and build number filled in (1.0, build 1).
- [x] Widget mention removed; it is not in this build.
- [ ] Confirm the reviewer-facing notes in `AppStoreAssets/LISTING.md` are
      pasted into the App Review Information field as well.
- [ ] Sign with whichever name you use in App Store Connect.
