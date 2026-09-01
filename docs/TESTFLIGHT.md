# TestFlight delivery setup

The `TestFlight Delivery` GitHub Action runs manually or for a `v*` tag. It creates
a temporary signing keychain, writes the NewsAPI value to an ignored xcconfig,
archives with Fastlane, uploads through the App Store Connect API, and deletes the
temporary config. GitHub's macOS runner is ephemeral.

## One-time Apple setup

1. Create the app identifier `in.sachinserver.News-App` in the Apple Developer
   portal and enable Background Modes as needed.
2. Create the matching app record in App Store Connect.
3. Create an App Store distribution certificate and App Store provisioning profile.
4. In App Store Connect create an API key with the minimum role that can upload
   builds. Download its private key once.
5. Verify version/build numbers and required privacy/export-compliance metadata.

## Required GitHub Actions secrets

| Secret | Meaning |
|---|---|
| `NEWS_API_KEY` | Newly rotated NewsAPI token |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded distribution `.p12` |
| `P12_PASSWORD` | Password protecting that `.p12` |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64-encoded App Store profile |
| `PROVISIONING_PROFILE_NAME` | Exact profile name used for this bundle ID |
| `KEYCHAIN_PASSWORD` | Random password used only for the temporary runner keychain |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | API issuer ID |
| `APP_STORE_CONNECT_KEY_BASE64` | Base64 content of the `.p8` private key |

Store secrets in a protected GitHub Environment if releases require approval.
Never print them, attach the generated xcconfig, or upload the temporary keychain.

## Release check

Run CI first. Then dispatch the workflow, watch App Store Connect processing, add
internal testers, and perform a smoke test covering launch, live fetch, offline
launch, bookmark persistence, deep link, large text, and VoiceOver. The workflow
being present is not proof of a delivered build; the processed TestFlight build is.
