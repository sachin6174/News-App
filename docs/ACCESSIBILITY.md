# Accessibility verification

Automated checks are committed, but accessibility is a human experience. Complete
this matrix on at least one small iPhone simulator and one physical device.

| Check | Exact action | Pass condition | Evidence |
|---|---|---|---|
| VoiceOver order | Enable VoiceOver and swipe through segment, story, bookmark | Reading order follows the visual order; each control has a purpose and state | Screen recording |
| Bookmark state | Focus an empty and filled bookmark | VoiceOver says bookmark/remove bookmark and explains the next action | Recording or notes |
| Dynamic Type | Settings → Accessibility → Display & Text Size → Larger Text → maximum | Titles wrap; no important text or controls overlap or disappear | Screenshots |
| Bold Text | Enable Bold Text and relaunch | Layout remains readable without clipping | Screenshot |
| Reduce Motion | Enable Reduce Motion, navigate list/detail | Navigation remains understandable and no information relies on motion | Test notes |
| High contrast | Enable Increase Contrast and switch light/dark mode | Text, banner, symbols and controls remain distinguishable | Screenshots |
| Switch Control | Move focus through main screen | Every action is reachable with a sensible target | Test notes |
| Hindi | Set app language to Hindi | Navigation, states, controls and errors use Hindi; layout still fits | Screenshots |
| Automated audit | Run `CriticalUserJourneysUITests/testAccessibilityAudit` | XCUITest reports no audit issue | `.xcresult` |

If an audit flags a third-party system view, document the exact OS/Xcode version;
never simply disable the entire audit. Exclude only a proven system false positive.
