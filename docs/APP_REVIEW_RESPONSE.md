# Draft reply for App Store Connect (Guideline 4.2.2)

**Before sending:** build and actually try the new features in Xcode on your
Mac first — nothing below has been built or run from the environment that
wrote it, only written and reviewed as source (see
`docs/REQUIREMENTS_MATRIX.md`). Adjust anything here that doesn't match what
you actually shipped, sign it, and paste it into the Resolution Center thread
for submission `55302a14-e3c6-4fee-954e-8b1ec7096112` alongside the new
build.

---

Hello,

Thank you for the detailed feedback on submission
55302a14-e3c6-4fee-954e-8b1ec7096112 (Guideline 4.2.2 — Minimum
Functionality). We understand the concern: the reviewed build showed
headlines aggregated from the internet with limited functionality beyond
that of a web feed.

We've updated the app to add native functionality on top of the article
feed:

1. **Personalized topics.** Readers can follow specific topics (Business,
   Technology, Sports, Health, Science, Entertainment) from a new Topics
   screen. The main feed now has a topic bar to switch between followed
   topics and the general feed, each with its own offline copy for reading
   without a connection.

2. **Breaking-news alerts.** With the reader's explicit, opt-in permission,
   the app posts a local notification when a new top story appears. Tapping
   it opens that exact story in the app.

3. **Listen to articles.** Every article screen now has a "Listen" control
   that reads the headline and summary aloud using on-device text-to-speech,
   for hands-free and more accessible reading.

These are implemented natively with Apple frameworks (UserNotifications,
AVSpeechSynthesizer, WidgetKit/UserDefaults for an in-progress Home Screen
widget) — the app has no third-party runtime dependencies.

We've uploaded a new build (version/build number: ____) with these changes.
Please let us know if there's anything else you'd like us to address.

Thank you,
Sachin

---

### Fill in before sending

- [ ] Confirm the new build actually includes these changes and passes a
      manual smoke test (follow a topic, receive/tap a test alert, use
      Listen) — see the checklist at the end of
      `docs/REQUIREMENTS_MATRIX.md`.
- [ ] Fill in the new version/build number above.
- [ ] Decide whether to mention the Home Screen widget. It is not wired into
      this build unless you completed the steps in
      `docs/WIDGET_SETUP.md` — if you skipped it, remove that mention from
      point 3's parenthetical above rather than promising a feature that
      isn't in the build Apple is about to review.
- [ ] Sign with whichever name/role you use in App Store Connect.
