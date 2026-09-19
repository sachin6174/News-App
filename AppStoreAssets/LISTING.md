# App Store listing — Newsly 1.0

Paste-ready copy for App Store Connect. Everything here describes what build 1
actually does. Nothing mentions the Home Screen widget: it is not in this build.

---

## Name (30 char max)

```
Newsly: Daily News Reader
```

(25 chars. If taken, fall back to `Newsly — Top Headlines` at 22.)

## Subtitle (30 char max)

```
Top headlines, even offline
```

(26 chars.)

## Promotional text (170 char max, editable without review)

```
Follow the topics you care about, listen to any story hands-free, and keep reading even when you lose signal. Your saved articles are always available offline.
```

## Description

```
Newsly is a fast, focused news reader for iPhone and iPad. It shows the day's top
headlines from established publishers, keeps the stories you save available offline,
and stays out of your way.

FOLLOW WHAT MATTERS
Pick the topics you actually read — technology, business, health, science, sports or
entertainment — and your feed reorganises around them. Switch back to the general Top
feed any time with one tap.

READ ANYWHERE
Stories you have already loaded stay readable without a connection, and anything you
bookmark is kept on device. Lose signal on a commute and your saved reading is still
there.

LISTEN INSTEAD OF READING
Any article can be read aloud, so you can catch up while cooking, walking or driving.

FIND IT AGAIN
Search across the headlines you have loaded, and keep the ones worth returning to in
Bookmarks.

BUILT FOR EVERYONE
Full VoiceOver support and Dynamic Type, so the app works with the text size and
assistive settings you already use. Available in English and Hindi.

PRIVACY
Newsly has no accounts, no sign-up and no tracking. Your bookmarks and topic choices
stay on your device.

Headlines are provided by NewsAPI. Tapping through to read a full article opens the
publisher's own website.
```

## Keywords (100 char max, comma-separated, no spaces)

```
news,headlines,offline,reader,topics,bookmarks,daily,breaking,tech,business,listen,rss
```

(86 chars. Do not repeat words already in the app name or subtitle — Apple indexes
those separately.)

## Support URL

```
https://sachinserver.in
```

## Marketing URL (optional)

```
https://sachinserver.in
```

## Privacy Policy URL — **required, does not exist yet**

Apple will not accept the submission without a reachable privacy policy. See the
note at the bottom.

## Category

- Primary: **News**
- Secondary: **Magazines & Newspapers**

## Age rating

Answer the questionnaire. For a general news reader the honest answers give **12+**,
because news content can reference violence, and the app links out to the open web.
Do not claim 4+.

## App Privacy (Data Collection)

Answer: **Data Not Collected.**

Build 1 has no analytics SDK, no accounts, and no third-party tracking. Bookmarks and
topic preferences are stored on device. The app calls one backend endpoint on
sachinserver.in, which proxies NewsAPI and does not attach a user identifier.

## What to tell App Review (Notes)

```
Newsly is a news reader. No account or login is needed — launch the app and the
current top headlines load immediately.

To review the main flows:
• The feed loads on launch. Tap a topic chip (Technology, Business and so on) to
  filter, or "Top" for the general feed.
• Tap any story to open the detail view, where the bookmark and "listen to article"
  controls are.
• The Bookmarks tab holds saved stories and works without a connection.

Headlines come from NewsAPI via a backend service at sachinserver.in. The API
credential is held server-side and is not present in the app binary.
```

---

## Before you can submit

1. **Privacy policy URL.** Required, and there is no page yet. The fastest fix is a
   simple page at `https://sachinserver.in/privacy` stating: no accounts, no
   tracking, no data collection, bookmarks stored on device, headlines fetched via
   NewsAPI. Say the word and I'll add it to the site and deploy.

2. **Do not mention the widget** anywhere in the description, keywords or
   screenshots. It is not in build 1.

3. **Screenshots** — 6.9" display (iPhone 17 Pro Max), minimum 1, up to 10. Generated
   set is in `AppStoreAssets/screenshots-6.9/`.

4. **NewsAPI terms.** Their free tier is for development, not production apps. If
   this listing goes live under the free plan it is a licence violation independent
   of anything Apple checks. Worth confirming your plan before release.
