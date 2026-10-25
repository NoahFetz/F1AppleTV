# Local validation guide

Use a full Xcode installation selected through `DEVELOPER_DIR` or `xcode-select`.
Run commands from the repository root. The suites use public catalog fixtures,
synthetic account/DRM responses and local unencrypted media; they do not need your
F1 TV credentials.

| Check | Command |
| --- | --- |
| Backend, authentication and FairPlay ownership | `bash Tests/run-backend-tests.sh` |
| Phone sign-in, device polling, refresh rotation and cancellation | `swift test --package-path F1Core --filter DeviceAuthenticationTests` |
| Catalog, presentation, settings, diagnostics and preview pool | `bash Tests/run-catalog-tests.sh` |
| FairPlay request format | `bash Tests/run-fairplay-tests.sh` |
| Playlist, rendition selection and preview playlists | `bash Tests/run-resolution-tests.sh` |
| Local AVFoundation playback (requires ffmpeg and Python 3) | `bash Tests/run-resolution-tests.sh --playback` |
| Credential migration and storage doubles | `bash Tests/Credentials/run.sh` |
| String catalog | `python3 Tests/verify-localizations.py` |
| Actual Alamofire transport with mocked responses | `F1_ALAMOFIRE_SOURCE=/path/to/resolved/Alamofire bash Tests/run-transport-tests.sh` |
| Multiview layouts, saved setups, default feed and Go Live | `bash Tests/run-multiview-tests.sh` |
| Remote timeline state, scanning and pending seeks | `bash Tests/run-player-interaction-tests.sh` |
| tvOS controller recovery, precise seeking, replay progress and idle guard | `DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer bash Tests/run-tvos-playback-tests.sh` |
| Shared package, desktop synchronization and saved windows | `bash Tests/run-desktop-tests.sh` |
| Desktop window geometry, pinning and control visibility | `bash Tests/run-player-window-tests.sh` |

The transport check needs an existing resolved Alamofire checkout; it does not
download packages. Signing is needed for simulator account/Keychain checks.
DRM-protected playback requires a physical Apple TV. Automated and simulator
results do not establish authenticated hardware compatibility.

Build and release automation now belongs to Xcode Cloud. The GitHub Actions
workflows and their custom Mac notarization/tag-packaging helpers were removed
on 2026-10-10. The local checks above remain available; configure hosted Cloud
test actions or verification scripts separately. Earlier release-workflow
validation notes below describe the tooling that existed at that time.

## Remote-friendly tvOS multiview controls (2026-10-25)

- The strip opens on Play/Pause. While playing, directional timeline clicks skip
  ten seconds; while paused, movement only previews. Select or Play/Pause confirms
  and resumes all streams. Back, leaving the timeline, dismissal and backgrounding
  cancel unconfirmed previews. The shared timeline uses the synchronization
  reference rather than the tile whose language/quality settings are selected.
- Holding a direction starts continuous scanning at 24/48/96 media seconds per
  second, labeled 2x/3x/4x. Swipes use relative time, without momentum. The optional
  thumbnail setting and timestamp-only default are unchanged.
- Audio opens an all-stream mixer. Each row is a single focus target: Up/Down
  navigates, Left/Right adjusts five percent, Select toggles mute, and Back returns
  to Audio. Level changes preserve mute and existing channel preference storage.
- The Foundation transport suite passes 14 tests, the real-controller simulator
  harness passes 42 checks, and the existing multiview suite passes 19 tests.
  The normal tvOS simulator build passes; 168 string keys validate in six languages.
- Device Hub virtual-remote checks verified row adjustment and vertical focus,
  Back-to-Audio, timeline preview/cancel, Down-to-controls, and Select-to-confirm
  synchronized local playback. Long-name/scrolling mixer screenshots are captured
  by the controller runner. Physical touch remotes, authenticated F1/FairPlay,
  and real live streams still require Apple TV testing.
- The controller runner normally removes its disposable simulator. Setting
  `F1_TV_KEEP_SIMULATOR=1` keeps that simulator and opens a local-video interactive
  strip after the checks; its ID is written to `simulator-id.txt` in the run folder.

## Optional scrub frames and CDN startup diagnosis (2026-10-09)

- Timestamp-only scrubbing is now the default for both custom player interfaces.
  Settings can enable frame previews. Legacy settings decode the new preference
  as off without changing feed-preview preferences. The scrub player is created
  only on demand and released when its preview closes; automatic warm-up was removed.
- Authenticated inspection confirms actual encrypted I-frame samples, not just
  advertised tracks: the sampled 480×270 preview fragment contained one frame
  and 15,035 bytes, versus 288 frames and 305,074 bytes for a matching regular
  segment. The 5.76-second frame cadence limits temporal precision.
- The existing app log showed playback and preview `NSURLErrorDomain -1102`
  failures at 16:48. A signed, sandboxed native probe reproduced the playback
  error with underlying `CoreMediaErrorDomain -12660`; AVFoundation's native log
  identified HTTP 403 Forbidden from media delivery. SDR failed on one run and
  HDR on another, while native-master playback succeeded. The reason for the
  intermittent CDN rejection is not established; stale entitlements are a
  recovery hypothesis, not a verified cause.
- Entitlement requests bypass caches. Mac preparation retries a confirmed CDN
  403 once with a fresh entitlement, retaining the original timeout and stale
  completion guards. License errors, cancellation and unrelated errors are not
  retried. Diagnostics retain safe HTTP status and underlying domain/code only.
  Exhausted failures keep a visible per-feed Retry state.
- **60 shared-core, 42 backend, 35 catalog, six FairPlay and 48 playlist/native
  playback tests passed**, including actual AVFoundation 403 metadata, bounded
  retry policy, legacy preference decoding and diagnostic privacy. Credential
  regressions and all 120 localization keys in six languages passed. Signed
  standalone Mac Debug and standalone tvOS Simulator builds passed.
- Running Mac Settings shows Scrubbing frame previews off. A local three-feed
  run issued fresh master requests after a rejected media playlist. Final feed
  state could not be confirmed because native UI automation lost its window
  binding when two development copies shared the same bundle identifier.
  Protected-playback recovery, physical Apple TV and protected live playback
  were not checked in this pass. No commits or pushes were made.

## Native protected scrub previews (2026-10-09, preceding optional default)

- Inspected authenticated Singapore Practice 1 and Sprint Qualifying HLS masters
  using the existing Mac session. Both advertise 13 I-frame renditions and no
  image playlists. The smallest SDR rendition is 480×270, with sampled frame
  intervals of 5.76 seconds. No credentials or signed URLs were saved to the repo.
- Reproduced `AVFoundationErrorDomain -11838` (operation not supported for asset)
  with AVAssetImageGenerator on the protected master. Generation from a direct
  I-frame asset timed out. The shared provider now renders that rendition with a
  separate paused, muted FairPlayer/AVPlayerLayer. Both custom scrub UIs host it;
  native tvOS fullscreen controls remain in place.
- The final provider produced ready protected replay layers at 120, 245 and 500
  seconds on this Mac, at 480×270. Main playback remained paused and its position
  unchanged. Warm runs took approximately 0.08–0.28 seconds; initial native-player
  preparation in the earlier independent probe took approximately 1.2 seconds.
- 47 playlist/native-playback checks pass, including continuous scrub request
  coalescing, cancel/reopen, independent audio/position, preview reset, low-resolution
  selection and program-date alignment after a main-feed seek. All 58 shared-core
  tests pass. Signed macOS Debug and standalone tvOS Simulator builds pass.
- Authenticated protected live previews, physical Apple TV rendering and manual
  pointer/remote interaction with the final UI were not exercised in this pass.
  Build and fixture results do not establish those runtime checks.

## HDR default, desktop styling and release workflow (2026-10-09)

- Automatic now requests HDR HLS variants on all displays, with single-range
  fallback retained. Display rendering remains standard-range on SDR screens;
  an explicit SDR source is still available. Startup quality preferences still
  determine the initial resolution.
- Sidebar icons explicitly follow the red selected-state styling, including
  Account, Settings and Error Log. Horizontal rows expand their viewport through
  the page padding while preserving first-card and heading alignment.
- Added independent macOS validation and manual Developer ID release workflows.
  Both release jobs validate/build the selected existing tag. The release job
  signs arm64/x86_64, notarizes, staples, validates Gatekeeper, then packages the
  final ZIP/checksum and optionally attaches them to a draft release.
- Universal unsigned Release archive and signed development build pass. The
  archived executable contains arm64 and x86_64. Workflow syntax passes actionlint
  (the documented preview xcode-27 label is allowed). Six offline packaging tests
  cover safe tags, accepted/rejected/timed-out notarization, debugger entitlement
  rejection, ticket-before-ZIP ordering and credential-file cleanup. Window tests
  pass and localization verifies 118 keys in six languages.
- Visual checks confirm the selected Home icon is red and catalog artwork reaches
  the right pane edge. Actual CI Developer ID signing/notarization and release
  publication were not performed in that pass. Its release instructions and
  GitHub workflow have since been removed. Changes remained local.

## Stream startup and standalone Xcode verification (2026-10-09)

- Reproduced protected startup failure using the stored browser session on this
  Mac: filtered SDR HLS failed with `NSURLErrorDomain -1102` and underlying
  `CoreMediaErrorDomain -12660`; the original service master played successfully.
  AVFoundation's default reference restrictions treat the custom-scheme,
  in-memory master as local. The corrected asset policy allows CDN media and
  custom FairPlay key references, retains remote-to-local restrictions, and the
  parser rejects `file:` and unsupported media schemes.
- With the final policy, the same protected stream reached ready-to-play,
  produced a ready AVPlayerLayer, and advanced playback time. The completed
  macOS app also started Singapore Practice 1 on the first attempt, advanced
  beyond 22 seconds, and displayed English audio. A failure warning was verified
  in the app. This establishes protected replay on this Mac; prolonged live
  playback, HDR fidelity and physical Apple TV playback remain separate checks.
- Desktop preparation now has a 45-second deadline and prepared feeds have
  20 seconds to begin playback. Deliberately paused groups do not expire the
  playback deadline. Failures stop that feed, display a catalog warning and
  player Retry state, and permit other feeds to continue. Attempt IDs reject
  stale errors/completions after close or retry. Optional track/HDR metadata
  refresh runs after transport joins, and first seeks use the coordinator's
  bounded seek handling. A first live feed may start before its seekable range
  appears so AVFoundation can populate the range and synchronize it.
- Inspected encrypted MP4 initialization segments for Singapore Sprint
  Qualifying (1000010389) and Practice 1 (1000010392). Their actual `encv` video
  sample entries are **2880 x 1620 SDR** and **3840 x 2160 HLG**, matching the
  HLS manifest. This is encoded video size, not an API display error. It does
  not establish a service-wide resolution limit. Credentials, media URLs and
  video data were not logged or saved.
- Reproduced `Missing package product F1Core` with both standalone Xcode project
  windows open. Closing both and reopening tvOS alone resolves package ownership.
  A fresh Xcode session built standalone F1A-TV for Apple TV 4K (3rd generation)
  successfully at 15:51. Opening both standalone windows simultaneously remains
  unsupported in this Xcode version; use the combined workspace for concurrent
  editing. Both projects retain their direct local package reference and build
  independently without the combined workspace.
- Final validation: **58 core tests**, **42 playlist/playback/preview tests**,
  macOS Debug build and tvOS Simulator Debug build passed. Added startup deadline,
  paused-start, stale-attempt, missing-range bootstrap, reference-policy and
  local-file rejection coverage. `git diff --check` passes. No staging, commits
  or pushes were performed.

## Authenticated range inspection and source organization (2026-10-09)

- Used the existing macOS browser session from Keychain to request real
  BIG_SCREEN_HLS entitlements and manifests. The Singapore Sprint Qualifying
  (1000010389) and Practice 1 (1000010392) manifests each contain seven HLG HDR
  variants (270p–2160p) and six SDR variants (270p–1620p), including separate
  1080p streams. Practice 1 Highlights and Tech Talk have AVC variants without
  VIDEO-RANGE; HLS treats omitted range as SDR. Only sanitized codec, resolution
  and range metadata was printed. Credentials and signed media URLs were never
  saved or logged. No account settings or stored sessions were changed.
- macOS now selects the actual HLS range together with resolution. Automatic
  follows the display; explicit HDR selects HLG/PQ and can be rendered in SDR on
  an SDR display. SDR selects the SDR variants. Menus report the available ranges
  and single-range fallback, and quality choices reflect the chosen range.
  macOS preview feeds explicitly prefer SDR. Existing tvOS callers retain the
  automatic/native range behavior.
- Native HLS range switching shares the quality-switch snapshot, audio/caption
  restoration, stale completion guards, timeout and rollback. Tests check
  same-resolution HDR/SDR filtering, range-specific quality lists, omitted-range
  SDR handling and single-range fallback. The live manifests establish variant
  availability; protected HDR rendering and visual HDR fidelity are separate
  checks and have not been verified on an HDR display.
- Reorganized physical macOS folders and Xcode groups into App, Catalog,
  Playback, Account, Settings, Diagnostics, Services, Appearance, Resources and
  Configuration. Updated entitlements, icon generation and test-script paths.
  Both projects have no missing file references. Removed 15 empty tvOS groups
  and 12 empty folders from disk, including newly empty parent folders.
- Both projects pass standalone command-line builds using `-project`, with
  direct local references to F1Core. macOS Debug and universal Release pass;
  tvOS Simulator Debug passes with dependency pins unchanged. The standalone
  F1A-TV project also built successfully in the Xcode GUI at 15:17. The combined
  workspace is optional for single-project builds and required to avoid local
  package ownership conflicts when editing both projects together.

Validation after the final changes: the resolution/playback/preview suite passes
40 tests (including native local HLS playback), F1Core passes 51 tests, and the
window/control suite passes. The unavailable-language test now sets an explicit
English automatic-selection criterion and checks the selected language after a
German manual override. This verifies fallback behavior independently of system
subtitle preferences and AVFoundation's bookkeeping flag.

HLS range metadata follows the
[Apple HLS authoring specification](https://developer.apple.com/streaming/hls-authoring-specification-for-apple-devices.html).


## Traffic lights, HDR output, dragging and Xcode recovery (2026-10-09)

- The window suite passes traffic-light hiding/reveal, cancellation of a
  superseded fade, native video drag hit testing, AVKit SDR rendering, and
  Automatic/HDR fallback on SDR displays. Existing idle, geometry and pinning
  checks also pass.
- macOS Debug and universal Release builds pass. Dynamic range changes only the
  AVPlayerView rendering policy, preserving session position and playback.
  Source HDR metadata is checked asynchronously with stale-item guards. Real
  HDR color reproduction and switching between HDR/SDR physical displays have
  not been validated with authenticated media.
- The actual Xcode GUI was switched from the stale standalone tvOS project to
  F1AppleTV.xcworkspace. F1Core loaded as a package, and the F1A-TV scheme built
  successfully for Apple TV 4K (3rd generation) at 1080p. The workspace is left
  open with that scheme selected. This goes beyond the previous CLI-only build
  verification. Dependency pins are unchanged.
- Both the normal Xcode build and fixture build contain AppIcon.icns and
  CFBundleIconFile/CFBundleIconName metadata. The app refreshes its runtime icon
  and AppKit's named-image cache from that resource. The native About panel was
  visually verified to show the red Vroom TV icon in the rebuilt fixture app.
- The running local HLS fixture hides the traffic lights together with the
  playback controls. Its dynamic-range menu reports the current C34H89x display
  as SDR and offers Automatic, SDR and HDR. These checks used an isolated app
  bundle and local media; authenticated HDR playback remains unverified.

To include the compiled icon check in the window suite:

```sh
F1_MAC_ICON_BUNDLE=/path/to/F1A-Mac.app bash Tests/run-player-window-tests.sh
```

## Desktop window behavior and shared Xcode workspace (2026-10-09)

- The native window/control checks pass: aspect-preserving restoration inside
  visible screen bounds, full-size content beneath the transparent title bar,
  floating/normal levels, idle hiding, mouse entry/exit, interaction holds,
  superseded timers and teardown cancellation.
- The isolated three-window HLS fixture showed video beneath the title bar,
  controls disappearing when idle, keyboard playback revealing them, and the
  Always on Top button reporting its active state. Native window zoom retained
  16:9, and fullscreen on the ultrawide display preserved the picture with
  side letterboxing; exiting restored the original window.
- macOS Debug/universal Release and tvOS Simulator build successfully from
  F1AppleTV.xcworkspace.
  The remote dependency pins are unchanged.
- Xcode's missing F1Core error was reproduced with both standalone projects
  open. Resolve Package Versions revealed the underlying diagnostic:
  **Couldn't load F1Core because it is already opened from another project or
  workspace**. Close those project windows and open the shared workspace so
  both schemes use one package graph. No package source or tvOS dependency
  versions needed changing.

## Desktop schedule, cards, icon and scrub thumbnails (2026-10-09)

- **51 shared-core tests passed**, including image-playlist tile decoding,
  two-second frame caching, shared sheet caching, superseded requests and reset
  cancellation. The existing 34 catalog checks pass.
- macOS Debug/universal Release and tvOS Simulator builds pass. Both applications
  now use the same CGImage thumbnail provider; the tvOS wrapper retains its
  existing UIImage presentation and supported rendition policy.
- **12 rendition-selection, six preview-playlist and 17 of 18 native playback
  checks passed**. The new scrub check loads an HLS image thumbnail while leaving
  the main player's time and paused state unchanged. The sole failure remains
  the previously reproduced automatic-caption-eligibility baseline assertion.
- In the isolated native app, one-/two-line card artwork, titles and metadata
  aligned. Clicking the hero artwork opened the event. The schedule showed day
  columns, equal-height session cards, series filters and disabled future events.
- Local native timeline dragging moved the linked session from 60 to about 122
  seconds while paused. Mid-drag bubble capture was not completed: the native
  automation intermittently lost the selected window. Thumbnail decoding,
  cancellation and isolation are covered by fixture tests; protected live/replay
  thumbnails still require real-account validation.
- The icon generator reuses the tvOS source, preserves its proportions, and
  outputs all ten standard macOS icon slots. Xcode packaged AppIcon.icns and
  Assets.car and set the bundle icon metadata. No source tvOS artwork was changed.
- Startup-quality labels use verbatim strings, preventing numeric grouping of
  1080p/2160p by SwiftUI's localized number interpolation.

The desktop fixture server now supplies an HLS JPEG image rendition for manual
scrub/hover preview checks. No account credentials were used. All work remains
local without staging, commits or pushes.

## macOS catalog parity and warm previews (2026-10-09)

The latest catalog/player refinements were checked separately from authenticated
playback:

- **49 F1Core tests passed**, including three artwork-size checks and ten preview
  coordinator checks: hidden warm feeds, immediate joins/reopening, paused intent,
  program-date alignment/fallback, replay/live-lag range clamping, buffering
  recovery, scrub/quality/pending-seek suppression, reference removal, unavailable
  references, timeout and stale completions after removal/reset.
- **41 backend, 34 catalog, 12 resolution-selection and six preview-playlist checks
  passed**; all 118 localization keys remain present in six languages.
- Native AVFoundation: **16 of 17 checks passed**, including both new cached
  preview checks. A preview plays the lower rendition from a cached manifest even
  when its master URL is unreachable; closing before cached preparation prevents
  the obsolete completion from installing an item. The remaining failure is the
  previously reproduced baseline assertion in
  `testAsynchronousDefaultsRespectUnavailableLanguageAndStaleOwnership`, where
  the current SDK reports automatic caption-selection eligibility differently.
- macOS Debug and universal Release and tvOS Simulator builds pass.
- In the isolated native fixture app, the season/home heroes retained artwork
  after entering and leaving fullscreen on the 3440-pixel-wide display. Formula 1
  headings, Titillium text, red accents/pagination, country flags and neutral
  action buttons rendered; the redundant title above the hero was absent.
- The local three-feed picker opened with warm thumbnails at the main feed's
  paused 60-second position, reopened without recreating those players and
  followed resumed playback. The language menu showed the selected audio and
  Captions Off checkmarks; selecting CC updated its active selection immediately.
  Menus refreshed after a local resolution switch. Local HLS does not validate
  real multilingual protected feeds.

The public resizer rejected the old 6400-by-720 artwork request with HTTP 400 and
accepted bounded requests. Desktop requests now preserve aspect ratio within a
2560-pixel limit and keep the last successful image during resizing. tvOS requests
retain their existing default sizing. Preview players stay separate from main
players, use their own FairPlay sessions, align every half second, and release
when their session ends. Hidden previews remain paused in a bounded warm pool.

Real authenticated sign-in, renewal/logout, protected live/replay playback and
physical trackpad input remain separate account/hardware checks. No credentials
were accessed for these refinements. No commits or pushes were made.

## macOS UI refinements (2026-10-09)

After the desktop UI and browser-first sign-in changes:

- F1Core: **36 tests passed**, including eight browser session tests for decoding,
  rejection of incomplete sessions, authorization headers, renewal, concurrent
  refresh, logout with failed fallback unregistration, stale refresh completion,
  cancelled credential writes and storage failures.
- Existing backend suite: **41 passed**. macOS Debug and universal Release builds
  and the tvOS Simulator build pass. The existing string-catalog check passes.
- A separate fixture app with its own bundle identifier and Keychain namespace
  verified the opposing hero arrows, changing artwork backdrop, Liquid Glass
  playback controls, searchable anchored feed popover, playing previews, paused
  preview alignment, focusing an existing feed, group keyboard pause/skip and
  independent quality changes while paused.
- The official F1 browser sign-in form loaded in the native sheet. Essential-cookie
  selection, cancellation and the collapsed manual fallback were exercised.
  No account identifier or password was entered.
- Horizontal input automation produced zero horizontal deltas, so physical
  trackpad paging remains a manual check. The AppKit handler supports phased
  trackpad input and discrete horizontal wheels, while retaining vertical scroll.
- Authenticated browser sign-in, real renewal/logout and protected replay/live
  playback require a real F1 TV account. Synthetic sessions and unencrypted HLS
  previews do not establish those results. The previously documented caption
  assertion failure on the current SDK remains a separate baseline finding.

## Shared core and macOS validation (2026-10-09)

Both applications now link the local F1Core package. The tvOS project retains its
existing project format and resolved dependency versions. Credentials, CoreData
migration, settings and the tvOS setup archive retain their original storage
contracts. macOS has a separate Keychain service and preference/setup archive.
For desktop playback fixtures, run `bash Scripts/serve-desktop-playback-fixture.sh`
from the repository root, then use **Development → Open Local HLS Fixture** in
the Mac Debug build with the loopback URL printed by the script.

| Check | Result |
| --- | --- |
| Backend/authentication/FairPlay ownership | 41 passed |
| Catalog/presentation/preferences/diagnostics | 34 passed |
| tvOS multiview and semantic setups | 19 passed |
| FairPlay license request format | 6 passed |
| Alamofire transport | 2 passed |
| F1Core package | 28 passed: 25 coordinator/window/setup checks and 3 networking/localization checks |
| Resolution selection and preview playlists | 12 + 6 passed |
| Native local AVFoundation playback | 14 passed, 1 existing caption-default assertion failed |
| Credential regression harness | All 9 scenarios passed |
| Localization | 118 keys in all 6 languages; compiled resource tables match in both apps |
| macOS Debug and Release | Build succeeded; Release contains arm64 and x86_64 |
| tvOS Simulator Debug | Build succeeded |

The native playback failure is
`testAsynchronousDefaultsRespectUnavailableLanguageAndStaleOwnership`, which
expects `mediaSelectionCriteriaCanBeAppliedAutomatically(to:)` to remain true
after an unavailable caption-language preference. The same assertion failed on
the untouched revision with the installed Xcode 27.2 beta 2/macOS SDK. It is not
an extraction regression. Overall, 162 of 163 XCTest checks passed, with the
credential harness and localization verification counted separately. Application
sources compile without warnings; Xcode still emits its App Intents metadata
notice and the existing two tvOS simulator linker warnings.

Coordinator coverage includes group transport, late joins in playing and paused
sessions, program dates and relative live lag, clamped seeks, the drift threshold,
buffer recovery, quality/scrubbing suppression, reference removal/failure,
readiness and seek deadlines, stale callbacks after reset/removal/retry, and
preserving an advancing or paused setup anchor. Setup tests cover missing feeds,
driver identity, invalid/offscreen geometry and independent tvOS storage.

Running macOS checks exercised public catalog artwork, featured paging, event
schedules and Back, settings, and browser sign-in preparation reaching
"Ready to sign in" without submitting credentials. A disposable app copy with
a separate preference domain played three generated HLS feeds. Group pause,
ten-second seeking, scrubbing, per-window volume/mute and quality selection,
native fullscreen, saving/restoring all three windows and their audio settings,
preserving the current paused position during restoration, cancellation of
session replacement, and closing the catalog while feed windows remained open
were checked. Playback and keyboard controls continued after closing the
reference feed and the catalog. Feed-picker search was checked; opening/focusing
its selected feed still needs a manual check because UI automation did not
reliably activate the picker row. Debug fixtures use the normal player preparation path without
requesting account entitlements; fixture routing is absent from Release builds.

The tvOS 27.2 simulator rendered Home, opened the current season and Singapore
event schedule, and returned through Back after package extraction. The existing
native local-media suite also exercised the shared FairPlayer implementation.

An International live feed was observed rendering in the main desktop app during
validation. That observation does not establish DRM protection, full sign-in or
refresh/logout compatibility. Authenticated fresh sign-in, refresh/logout,
protected replay, sustained linked live playback, real language/caption tracks,
and physical display reconnection still need a signed real-Mac check. Physical
Apple TV navigation/playback and DRM remain separate device checks. Synthetic
responses, local HLS and builds do not establish those results.

The dated notes below record validation of individual changes. Later notes
supersede earlier test counts, warning counts and implementation details; the
FairPlay content-key migration is the latest DRM implementation described here.

## Multiview feature validation (2026-10-02)

The new multiview suite has 19 passing tests covering layout geometry through
32 streams, capacity handling, default-feed migration/fallback, semantic channel
matching across sessions, saved setup persistence and audio, and live-window
positioning. Controlled live-session doubles cover program-date synchronization,
different media origins, moving seekable windows, pending players, cancellation,
stale callbacks, date-seek fallback, and bounded readiness failures.

All existing suites also pass: 34 catalog, 41 backend, 6 FairPlay request,
33 playlist/local playback/preview, and 2 Alamofire transport checks (135 XCTest
checks in total). Credential regression checks and all six localization checks
pass separately. Existing test-only diagnostic deprecation/concurrency warnings
and an Alamofire source warning remain; the app sources build without warnings.
Unsigned generic tvOS and tvOS Simulator builds pass. Xcode also emits its
App Intents metadata notice and two simulator linker address warnings; neither
is an app-source compiler warning.

An isolated tvOS 27.2 simulator harness using generated unencrypted media passed
22 additional assertions for player reuse, layout changes without restarting,
paused playback, setup ordering, and saved volume/mute restoration. Simulated
remote checks exercised the layout selector, disabled undersized layouts, empty
Add stream slots, Grid selection, and the saved-setup actions. The native
fullscreen Resolution and live-action controls are present together. The harness
also verified the default-feed choice sheet in Settings and clearing the red
editing indicator when closing the controls.
It uses its own bundle ID and local setup store; it does not submit credentials.

Physical Apple TV checks remain necessary for authenticated F1 Live/default-feed
startup, protected/unprotected playback, real moving live windows/program dates,
pending DRM players joining Go Live, and concurrent decoder/preview performance.
Synthetic responses, local media, and simulator builds do not establish those
behaviors on an authenticated device.

Multiview control polish (2026-10-02): Layout and Saved setups now use native
icon/text buttons inside the shared glass panel. Empty layout slots use a compact
native glass Add stream button rather than highlighting the entire tile. Stream
selection appearance changes only on a state transition; repeated remote presses
refresh the idle timeout without restarting the border or label animations.

The tvOS and simulator builds pass. The isolated local-media harness still passes
its 22 player/setup assertions plus five additional checks for the new slot cell,
visible editing state, no restarted border/label animations after 20 repeated
updates, and keeping the editing indicator visible past the idle timeout.
Simulated remote checks verified session-action focus within the glass panel,
navigation from a stream into both empty slot buttons, opening the channel picker,
and Back restoring slot navigation. These checks used unencrypted generated video;
physical Apple TV appearance and remote behavior remain to be checked.

## Resolution selection tests

Run with an installed Xcode selected (or set `DEVELOPER_DIR`):

```sh
bash Tests/run-resolution-tests.sh
bash Tests/run-resolution-tests.sh --playback
```

The first command runs the playlist and selection-state XCTest suite. The optional
playback suite requires `ffmpeg` and `python3`; it generates temporary unencrypted
HLS fixtures, serves them on an ephemeral localhost port, and exercises the real
`FairPlayer` using macOS AVFoundation. The server and fixtures are removed on exit.
Network/AVFoundation access may require running outside the Codex sandbox.

Playback checks cover highest-resolution startup, fixed-resolution switching,
paused position, playback rate, mute/volume, rollback, redirected master URLs,
independent players, stale requests, and closing during discovery or switching.
The test stubs do not request FairPlay licenses or access account credentials.

Preview checks cover advertised image/I-frame renditions, signed relative URLs,
JPEG sprites, tile boundaries, live program dates, malformed image playlists,
and lower-resolution preview playback without changing the main player's default.
Fixed-resolution filtering retains independent trick-play renditions. Scrub
previews use the provider's image playlists or HLS I-frame extraction, with a
time-only fallback when no usable preview is available. The stream picker
prepares muted low-resolution previews for visible tiles plus
one neighbouring tile at each end. Visible previews follow the selected open
player; neighbouring previews stay paused. Artwork remains until the first frame.

These tests and the tvOS simulator build do not verify authenticated F1 streams,
live program-date positioning, real language/subtitle selection, or physical Siri
Remote behavior. Check those on Apple TV in both viewers, including entering and
leaving fullscreen and adjusting the volume slider while the strip is open.

# Catalog browsing tests

```sh
bash Tests/run-catalog-tests.sh
bash Tests/run-fairplay-tests.sh
```

The catalog suite decodes ten public catalog page fixtures plus a sanitized menu
fixture using the production DTOs
and tests section/item order, poster and thumbnail layouts, API-supplied series
links, URL query preservation, banner behavior, and schedule filtering,
deduplication, local calendar grouping, and availability checks.

Catalog page requests use WEB_HLS independently of the playback provider.
Horizontal layouts use scrolling rows; vertical and flat result layouts use
grids. The hero pages manually. The schedule starts expanded and displays times
in the device's timezone. Search, My List, and watch-history integration are
outside this change.

Check on Apple TV: hero paging and Select, poster and series destinations,
View all and Back with focus/row restoration, season/archive grids, and the race
banner followed by schedule filters and Collapse/Expand. Selecting a schedule
session must enter the existing video/feed-selection flow; disabled sessions
must not play. Protected and older unprotected playback require authenticated
physical-device verification; fixture tests and simulator builds do not prove it.

Manual catalog verification on the tvOS 27.2 Apple TV 4K simulator (2026-09-30):
hero paging and captions, Home poster rows, API series tiles and Formula 3
navigation, season grids, the Azerbaijan banner, ALL/F1/F2 filters,
Collapse/Expand, session and day navigation, and View all grids were checked
with the simulated remote. Returning from destinations restored the focused
card and horizontal row position. Session selection reached the existing
subscription check in the unsigned-in simulator. Authenticated feed selection,
live/start options, playback return focus, and protected/unprotected playback on
a physical Apple TV remain to be checked.

Navigation/settings/preview validation (2026-09-30): the production menu decoder
and language cache, legacy settings migration and persistence, bounded preview
window, session release/deduplication, stale preparation completions, and reference
player changes are covered by 19 passing catalog tests. Pool ownership tests use
controlled session doubles; they do not test real entitlement or decoder load.
12 playlist/selection, 11 local AVFoundation playback, 6 preview-playlist, and
6 FairPlay request tests pass. Local playback includes startup quality caps and
native playback when resolution metadata is missing. The tvOS simulator build
passes.

Simulator remote checks include menu Select/collapse, highlighted versus active
navigation, cached season browsing, GP flags, hero paging/dots/background changes,
header Up/Down with remembered row items, View All destination/Back focus,
Left from headers to the rail, Account/Login presentation, Settings initial focus,
quality choices and grouped controls, and About with app version/disclaimer. Login credentials were not
submitted. Physical Apple TV login, real audio/subtitle availability, protected
and older unprotected playback, live/start choices, the 3.5-second multiview focus
fade, live program-date synchronization, and smooth concurrent preview decoding
remain authenticated physical-device checks.

# Browsing refinement and diagnostics validation

Validation on 2026-10-01: 30 catalog/presentation/settings/error-history tests,
12 playlist/selection tests, 11 local AVFoundation playback tests, 6 preview
playlist tests, and 6 FairPlay request tests pass (65 total). The tvOS simulator
build passes. Presentation checks cover adjacent title/subtitle grouping,
duplicate heading suppression while retaining distinct subtitles, selected-item
header fallbacks, existing banner reuse, and horizontal bounds for spatial focus.
Error-history checks cover persistence, seven-day retention, the 100-entry limit,
60-second coalescing, concurrent insertion, clearing, malformed data, safe-field
sanitization on insertion and reload, cancellation exclusion, and recording before
custom failure handlers. Stale failure handlers are ignored.

Simulated remote checks on tvOS 27.2 include the native table rail, focus without
opening a destination, Select/collapse, neutral controls, artwork-only posters,
full-width destination heroes and race headers, compact grouped headings, and
the readable multiline More screen. Left and middle cards skip unaligned View
All actions; aligned right-hand cards can reach them. Down from an action returns
to its remembered row item, and Back restores the originating card/action and
horizontal row position. Race schedule filtering and Collapse/Expand still work.
Settings Diagnostics shows saved errors, timestamps, safe technical details, and
the Clear history confirmation; cancellation preserves the entries. History also
survives installing the updated build and relaunching the simulator app. Explicit
action errors remain in a native alert until dismissed.

Automated checks do not establish recovery from a real
network outage. Authenticated physical Apple TV login, DRM and older unprotected
playback, live/start behavior, playback return focus, and concurrent preview
performance remain unverified. No credentials were submitted during these checks.

Subpage refinements (2026-10-01): 32 catalog tests pass and the tvOS build passes.
The two added checks cover View All overflow/exact-fit decisions for rows and
grids, additional backend items, and selected-event artwork with a returned-banner
fallback. Subpages now remain inside the shared sidebar container, with a retained
navigation stack for each topic. Event artwork fills the background behind the
floating title, flag, dates, and schedule instead of appearing in a separate header
image container. Home's saved background preference is unchanged.

Simulator remote checks verified opening an event with its sidebar available,
switching to Shows and back to the retained event, and Back restoring the Season
Explore action. View All destinations retain the rail, and Back restores their
originating header action. A fitting single-item section hides View All while
overflowing Tech Talk rows retain it. Physical-device playback was not retested
for these browsing-only changes.

Background and event-scroll polish (2026-10-01): the tvOS simulator build and
32 catalog tests pass. Fullscreen backgrounds use a subtle radius-2 blur;
foreground artwork remains sharp. The most recent successful catalog background
is retained in memory and written atomically to the app's local cache for reuse.
Without cached artwork, a generated dark racing-stripe background replaces the
old tire placeholder. Swift placeholder references use this shared fallback.

Simulator remote checks verified 24-point sidebar edge insets with fully readable
English labels, cached event artwork behind Account, and Up from the lower event
rows back to the entire floating title and dates. Both expanded and collapsed
schedules were exercised. The floating header provides a focus anchor so tvOS
does not immediately recenter a lower schedule control; Down returns to schedule
controls and Left still reaches the rail. The local cached-artwork file was also
verified. Physical Apple TV playback was not retested for these UI changes.

Collapsed rail and scroll animation follow-up (2026-10-01): the native navigation
table now uses 8-point horizontal insets while collapsed and 24 points while
expanded. This leaves the compact highlight 80 points wide rather than squeezing
its rounded ends into 48 points. Simulator checks verified Home and Season active
highlights after collapse, expanded labels, and repeated expand/select/collapse.

Removed the forced schedule-controls-to-header scroll. The focusable event header
now participates in native animated scrolling; an already instantiated schedule
or header is focused without first changing the content offset. Offscreen fallback
routing is retained for content the focus engine cannot discover. Simulator remote
checks returned from lower rows to the full title and dates with both expanded and
collapsed schedules, then Down to the controls. The tvOS simulator build passes.
Physical-device animation smoothness and playback were not retested.

# Backend service refactor (2026-10-01)

Run with a full Xcode selected through `DEVELOPER_DIR` if the system default points
to Command Line Tools:

```sh
bash Tests/run-backend-tests.sh
F1_ALAMOFIRE_SOURCE=/path/to/resolved/Alamofire bash Tests/run-transport-tests.sh
bash Tests/Credentials/run.sh
bash Tests/run-catalog-tests.sh
bash Tests/run-fairplay-tests.sh
bash Tests/run-resolution-tests.sh --playback
```

The transport suite compiles the resolved local Alamofire checkout, does not fetch
packages, and uses URLProtocol responses. The backend suite injects transport,
authorization, credential storage, challenge providers and controlled async gates.
Backend account, entitlement and video fixtures are entirely synthetic; tokens,
URLs and account fields are placeholders. Catalog fixture checks now decode the
new wire layer and map into Foundation-only app models.

The backend checks cover methods/providers/headers/bodies and encoded queries,
HTTP-200 backend rejection before payload decoding, required versus optional
fields, mixed IDs/timestamps, malformed siblings, stable item/channel identities,
safe contextual diagnostics, cancellation, bounded GET retries and non-replayed
POSTs. Authentication checks cover shared refresh, preserved device headers,
repeated/failed 401, non-refreshing 403/reporting, logout during refresh or an
already-running credential write, superseded login, account state, storage errors
and retryable logout cleanup. Certificate/license/resource checks cover shared
certificate loading, canceled waiters, later retry after failure, exact license
requests, CKC decoding, independent entitlements and stale SPC/CKC cancellation.
The existing credential script checks CoreData-to-Keychain migration, storage
failures, preserved existing values, insert races and retryable logout cleanup.

All 102 XCTest checks pass: 32 catalog/presentation/settings/diagnostics/preview
pool checks, 33 backend service checks, two actual Alamofire transport checks,
six FairPlay request checks, 12 resolution checks, 11 local unencrypted
AVFoundation HLS playback checks and six preview-playlist checks. The separate
credential regression script passes all nine scenarios. The final ad hoc signed
tvOS simulator build and unsigned generic tvOS target build both pass.

Simulator checks with the refactored services include backend menu/season
navigation, event artwork and schedule mapping, destination Back focus, poster
rows, persistent action errors with Retry, Account storage-failure recovery,
Settings and retained Error Log entries. The existing browser challenge reached
“Ready to sign in”; no fresh credentials were submitted. An unsigned simulator
build returned Keychain status -34018 (missing entitlement), surfaced in Account
and safe diagnostic details instead of being treated as signed out. Ad hoc
signing restored access to the existing saved registration: Account showed the
existing profile and active subscription without requiring a new login.

Using that saved session, a Home video and an available Weekend Warm-Up schedule
session played through the native viewer; Back restored their originating
selection. The Australian race replay played in the multiviewer. Its visible
International Feed and F1 Live previews advanced alongside the main playback;
the Tracker preview also displayed video. Closing the selector and viewer
returned to the event catalog. These observations establish real simulator
entitlement/media loading, but do not establish FairPlay protection for the
selected streams or sustained physical-device preview performance.

Physical Apple TV login, protected and older unprotected playback, live/start
behavior, real media preferences and concurrent preview performance remain
unverified. Build and synthetic/local HLS results do not establish those outcomes.

# Project, localization and artwork cleanup (2026-10-01)

Xcode's loose path-shaped source references now live in their matching Models,
Networking/Wire, Networking/Services and controller groups. Source locations and
target membership are preserved. All 127 Swift/catalog file references resolve.

`F1A-TV/Localizable.xcstrings` replaces the six legacy Localizable.strings tables.
All 91 keys and 546 translated values match the previous source tables exactly;
Xcode's compiled tables also match. Existing key-based lookup, API language codes
and locale identifiers remain unchanged. To verify the catalog and a built app:

```sh
python3 Tests/verify-localizations.py --app /path/to/F1A-TV.app
```

Catalog cards no longer use the last fullscreen backdrop as a loading placeholder.
Reuse clears text, artwork, accessibility labels and pending image identity.
Artwork loads at the final image-view bounds, using the screen's pixel scale and
the card's 2.5% focus enlargement. Requests round up to eight-pixel buckets and
decode to that budget; heroes, posters, banners and destination headers share
the same sizing policy. Fullscreen backgrounds use their display pixel dimensions
and retain their existing blur and crossfade. A public 3840×2160 artwork request
returned a 3840×2160 image; intrinsic source quality still depends on the backend.
Nearby collection items prefetch artwork with the same cache keys, and obsolete
prefetches stop when their window or page changes. No account headers are added.

The updated catalog suite passes 34 tests, including native-pixel sizing, focus
enlargement, 4K backdrop sizing and invalid/missing artwork inputs. The signed
tvOS simulator build passes. Simulator remote checks exercised Home heroes,
Shows portrait posters, rapid movement through thumbnail rows, and return to
cached rows. First loads showed neutral placeholders and then matching artwork;
returning rows showed their matching titles and images. Physical Apple TV image
quality and animation timing were not checked during this cleanup.

### Login field surface verification (2026-10-02)

Login fields now use the native tvOS surface with inset text and focus-aware
text/placeholder colors. Removing the custom background and rounded border
avoids a second gray layer behind the system bezel. The signed tvOS simulator
build passes. Remote focus was checked on both fields; the native Email → Password
keyboard flow preserved entered text and masked the password.

Fresh sign-in was attempted on an isolated simulator using the authorized account.
The server returned HTTP 200 JSON without the required PhysicalDevice, SessionId
or data registration fields, so the app retained its inline failure and recorded
a decoding diagnostic. This does not establish whether the supplied credentials
were accepted. Response contents and account secrets were not saved to fixtures
or logs. Temporary response-shape instrumentation was removed. Physical Apple TV
sign-in and playback were not verified by this check.

### FP1 entitlement license-field regression (2026-10-02)

The active FP1 entitlement returned its FairPlay license address under `laURL`.
The refactored DTO only decoded `laUrl`, discarded that address, and rejected
the otherwise valid entitlement with Application code 1005. Explicit coding keys
now support the backend spelling plus the legacy spelling, preserving the signed
license address unchanged. Strict stream/token/channel/license validation remains.

All 34 backend tests and six FairPlay request tests pass; the signed tvOS
simulator build passes. A synthetic fixture covers canonical casing and encoded
license query parameters, while the existing fixture retains legacy coverage.
Retrying the same FP1 item now passes entitlement loading and reaches AVFoundation,
which reports CoreMediaErrorDomain 1718449215 (`fmt?`) on the simulator. No new
entitlement rejection was recorded. This verifies the decoder fix, not successful
protected playback. Physical Apple TV FairPlay playback remains unverified.
Temporary schema probes were removed; no tokens or signed URLs were logged.

## Xcode warning cleanup (2026-10-02)

A clean tvOS Simulator build with Xcode 27.2 beta 2 reduced app-source warning
locations from 24 to one. Audio/caption groups and display criteria now use
asynchronous AVFoundation loading, with cancellation and item/operation identity
checks. UIKit uses scene/trait screen information and button configurations.
The remaining source warning belongs to the existing FairPlay resource-loader
SPC API; moving that path to AVContentKeySession requires a separate DRM
migration and authenticated physical-device verification. The build also emits
two x86_64 linker diagnostics and an App Intents metadata extraction warning.

`bash Tests/run-resolution-tests.sh --playback` passes 12 playlist/selection,
13 local AVFoundation playback, and six preview-playlist checks. New generated
English/German WebVTT fixtures verify asynchronous track selection, caption
restoration across resolution changes, captions Off, startup preferences,
unavailable-language fallback, and stale ownership. Simulator remote checks
confirmed the hero and Settings buttons retain neutral focus styling and rail
selection still opens only on Select. Physical Apple TV DRM and playback were
not retested for this cleanup.


## FairPlay content-key migration (2026-10-02)

The deprecated resource-loading SPC API has been replaced with
`AVContentKeySession` and asynchronous `AVContentKeyRequest` SPC generation.
Assets are registered before loading, renewals follow the existing license flow,
and player/preview/thumbnail sessions remain independently owned and ephemeral.
The license POST body, headers, asset-ID normalization and CKC decoding are unchanged.
Canceling key generation resolves its awaiting task immediately; later or duplicate
native completions are ignored. Superseded requests cannot exchange or deliver
an old license. Native requests retain their owning session until SPC completion.
The tvOS Simulator rejects FairPlay session construction; an explicit platform
guard avoids that Objective-C exception.

The clean tvOS Simulator build has zero app-source warnings. Two x86_64 linker
diagnostics and the App Intents metadata extraction warning remain.
All 39 backend/native-session checks, six license-request checks and 31 local
playlist/playback checks pass. Added checks cover native identifier mapping,
independent asset recipients, lazy certificate/license loading, idempotent
invalidation, cancellation during SPC, duplicate completions, generation
supersession and SPC failures. These checks do not establish authenticated
physical Apple TV FairPlay playback, live behavior or concurrent DRM performance.

The hardware tvOS target also builds without app-source warnings. After adding
the simulator guard, a protected Practice 1 attempt produced a dismissible
playback error rather than the native session-construction crash. This does not
verify successful protected playback. The simulator build retains its linker
warnings; the hardware build only emits the App Intents metadata warning.

## Physical-device key-routing investigation (2026-10-02)

The paired tvOS 26.6 Apple TV's saved diagnostics contained three playback
failures with NSURLErrorDomain -1102, without a recorded certificate/license
failure. Its console output alone did not identify the failed resource. Device
Hub cannot mirror this device because screen sharing requires tvOS 27; diagnostics
were read from the app's preferences without accessing Keychain credentials.

Apple's AVAssetResourceLoaderDelegate contract requires a delegate installed on
an AVContentKeySession recipient to classify custom key requests with
AVStreamingKeyDeliveryContentKeyType and finish the loading request. The migration
had returned false for `skd` requests. The delegate now performs that handoff and
forwards resource renewals through the same handler; SPC/CKC work remains in the
native session. This fixes a contract violation consistent with the observed
resource-loading failure; recovery on the affected hardware is not yet verified.

All 41 backend, six license-request and 33 playlist/playback/preview checks pass.
The new policy checks cover key classification, exactly-once handoff, unowned
keys and unrelated resources. Synthetic HLS fixtures exercise certificate
callbacks for both native and filtered protected manifests, then deliberately
fail certificate loading before SPC/license generation. These tests do not
decrypt protected media or reproduce every hardware loading path. The generic
tvOS build passes with no app-source warnings; its existing App Intents metadata
warning remains. Retry the affected streams on a physical Apple TV using the
updated build to confirm intermittent startup, renewals and concurrent previews.

## Preview lifetime and catalog parity (2026-10-10)

Scrubbing retains one independent paused, muted native preview player per active
feed after its first request. Default suspension has no idle expiry; closing or
replacing the feed resets the provider. tvOS owns the provider in `PlayerItem`,
across control-overlay presentations, and resets feeds removed by saved layouts.
Both custom clients mount the native preview surface during loading and can retry
confirmed HTTP 403 failures once with fresh preview access. The standalone tvOS
AVKit player explicitly permits native controls/scrubbing, independently of the
custom preview preference; native thumbnails still require usable stream tracks.

Validation: 60 F1Core tests and 54 local HLS/playlist tests passed. The new native
lifetime check retains the identical paused player beyond the former 15-second
expiry, reuses its renderer, and verifies reset releases it without seeking the
main feed. Mac, tvOS Simulator and physical-target tvOS Debug builds passed.
Mac UI checks covered native row highlighting, sidebar reselection, the filled
Home icon, conditional Back, and event metadata over background artwork. tvOS simulator checks covered
video duration/category plus description and event country/date/round metadata.
Signed-in Mac account fields and successful authenticated protected scrubbing on
physical Apple TV were not runtime-verified. Existing build warnings remain.

Mac hover follow-up: leaving the narrow timeline now hides the preview without
cancelling first-frame preparation. The SwiftUI overlay remains mounted while
hidden, preserving the native video host and paused renderer for re-entry.
Failed previews may retry on a new hover session, while continuous pointer
movement cannot repeatedly restart rejected assets. Closing the feed or disabling
previews still resets all preview work. The Mac build and 56 local HLS/playlist
checks passed, including two Mac model regressions for hover exit/re-entry and
rejection/cleanup. Authenticated protected preview rendering was not exercised;
the Mac Error Log also contained historical preview HTTP 403 rejections.


## Issues #89 and #90: tvOS playback recovery and idle prevention (2026-10-10)

- The isolated tvOS regression app exercises the actual controllers with local,
  unencrypted video and mock services. Its 24 checks pass: precise late joins,
  superseded seeks, preview-only scrub adjustment followed by a shared seek,
  thumb stability during pending/repeated seeks and release after completion or
  cancellation,
  playback/pause/fullscreen/foreground idle ownership, failed-layout recovery,
  restart position and audio restoration, tile retry, picker removal, and final
  replay reporting after exit. The runner creates and removes only its own
  simulator and uses a separate app identifier. It needs ffmpeg and a compatible
  installed tvOS simulator runtime.
- The native regression reproduced a joining feed landing at 10 seconds when
  the main feed was at 8 seconds. Synchronization and saved-position seeks now
  use zero tolerances. Per-feed seek IDs discard obsolete callbacks, including
  canceled restoration seeks during restart. Startup failures/timeouts remain
  removable and retryable. Scrub touch sensitivity is reduced and momentum is
  disabled; actual seeking happens on release. Timeline refresh preserves the
  scrub position until the displayed feed finishes seeking, including secondary
  synchronization, so gesture release cannot briefly restore the old position.
- No existing app code disabled AVPlayer display-sleep prevention. Playback now
  explicitly enables it and has an additional idle-timer guard for real feeds,
  including buffering, pause, failure, fullscreen ownership and foreground
  transitions. Physical Apple TV screensaver timing still requires verification.
- Replay progress has an owned, serialized reporting queue: exiting cannot
  cancel the final report or drop it behind an in-flight intermediate report.
  Start-from-beginning no longer gets overwritten by a stored resume position.
- F1 Live has an independent named audio-track default. Actual track names are
  discovered during playback; missing named choices fall back to existing
  additional-feed settings. Legacy settings retain their behavior. Authenticated
  F1 Live commentary selection and physical remote sensitivity are unverified.
- Shared-core tests: 64 passed. Multiview model/live-coordinator tests: 19 passed.
  Native resolution/playlist/playback tests: 56 passed with normal AVFoundation
  and localhost access; sandboxed media loading was denied by the environment.
  tvOS simulator and device-target builds passed. All 128 localization keys
  verify in six languages. These results do not establish FairPlay playback or
  physical Apple TV behavior. Changes are left uncommitted.

## Issue #91: phone sign-in on tvOS (2026-10-22)

The TV login screen now uses F1's device authorization flow. It displays the
provider's QR URL and user code, waits for phone approval, and supports a new code,
cancellation and expiry. Completed credentials are stored in Keychain; the app
never receives the password entered on the phone.

- All **82 shared-core tests pass**, including 18 device-authentication tests for
  provider intervals/backoff, denial/expiry, cancellation, superseded codes,
  persistence failure, refresh rotation, concurrent refresh, logout ownership,
  authorization headers and F1's actual refresh response shape.
- All **24 existing tvOS controller playback regressions pass**.
- A signed isolated simulator app completed real phone approval and Keychain
  persistence. After fixing the refresh-response decoder, its **10 final checks
  pass**: QR generation/decoding and cancellation, Keychain storage, real OAuth
  renewal, restored credentials, authorized replay metadata/entitlement, native
  decoded replay video after renewal, and logout cleanup. The QR/cancel checks
  use a synthetic code; the renewal/playback checks use the approved live session.
- A separate native probe also renewed the live OAuth credential, fetched replay
  metadata with 26 channels and a playback entitlement, and decoded 1280×720 video
  while the playback clock advanced. No account secrets were added to fixtures,
  source or logs. The isolated apps use their own simulators, which are removed
  after the checks. The app builds successfully and all six translations pass.

F1 currently returns an OAuth access token valid for one hour and a separate
subscription/playback JWT valid for four days. Refresh rotates the OAuth
credential but omits the playback JWT, even when requesting the original scope.
The app retains the existing playback JWT only until its original expiry. If F1
does not reissue it at expiry, the session is cleared and a new phone pairing is
required. Native playback verification used a replay; protected FairPlay/live
playback and physical Apple TV behavior remain separate checks.

## macOS OAuth sign-in and renewal (2026-10-22)

The Mac now signs in on F1's official page in its native browser sheet and stores
OAuth refresh/playback credentials in a separate Keychain record. F1's web OAuth
client successfully exchanges a PKCE authorization code but does not issue a
refresh token, even with `offline_access`. The Mac therefore opens the device
grant's `verification_uri_complete` locally. After credential entry, it completes
only the matching, prefilled verification automatically. There is no phone, QR
scan, code entry or additional confirmation click in the Mac flow.

`Tests/run-mac-oauth-tests.sh` runs the production Mac browser code and Keychain
store in an isolated app identity. Its **16 checks pass**: automatic verification,
host/route/code matching, delayed prefill, one-time approval, error recovery,
main-frame-only injection, ephemeral cookie isolation, retry/cancellation races,
and Keychain restoration/clearing. It uses synthetic credentials and never reads
the production Mac Keychain service. The verification helper never reads website
passwords or tokens.

The final automatic-verification flow was also completed in a live Mac sign-in
without an extra confirmation click, and all eight live checks passed again.
The production Mac and tvOS simulator targets both build successfully.

All **83 shared-core tests pass**, including coverage for discarding superseded
browser/registration credentials. A real Mac sign-in also passed **eight checks**:
playback/refresh token issuance, Keychain persistence, a real OAuth refresh,
restoration from Keychain, replay metadata and entitlement, native decoded video
with the renewed login, and sign-out cleanup. OAuth expiry was advanced only in
the isolated Keychain record to exercise renewal; the actual playback JWT's
expiry was preserved. The existing four-day playback-token limit still applies
when F1's refresh response omits a replacement subscription JWT.

Existing browser sessions remain usable. Account offers a fresh sign-in to enable
OAuth renewal. Password/challenge preparation and website localStorage polling
are no longer used for new Mac sign-ins.

## macOS sign-in completion latency (2026-10-25)

The Mac previously polled throughout browser sign-in and could leave F1's
completed page visible until the next provider interval (observed as five
seconds). It now observes F1's exact HTTPS completion route, including in-place
hash navigation, and starts its first token request immediately. This uses the
browser return channel described in RFC 8628 section 3.5. If the server still
returns `authorization_pending` or `slow_down`, subsequent requests retain the
provider's interval/backoff rules. tvOS keeps its original polling behavior.

A native “Finishing sign-in…” indicator replaces the completed webpage while the
request and Keychain save finish; the completion page alone never signs the
account in. Polling starts after a one-minute fallback timeout if the browser
completion cannot be observed. Cancellation/retry also clears the completion
observer and waiter, so an older window cannot complete a newer attempt.

Validation: **86 shared-core tests** and **32 native Mac OAuth checks** pass,
including immediate first retrieval, pending/slow-down intervals, expired/stale
approval, F1-style same-document navigation, origin/route rejection, deferred
polling, token/persistence gating, cancellation, failed exchanges and fallback.
The Mac and tvOS simulator targets build successfully. This timing change was
verified with native browser fixtures;
another authenticated F1 sign-in was not requested.

## Login and account localization audit (2026-10-25)

The TV pairing instructions already used the shared catalog. The Mac account,
browser sheet, renewal prompt, progress states, sign-in/sign-out failures and
injected verification status now also use F1Core translations. Account labels,
subscription-state display names and country names are localized on both
platforms. Unknown server subscription states display a translated “Unknown”;
entitlement decisions continue to use the original server value.

There are **161 keys in all six supported languages**: English, German, Spanish,
French, Dutch and Portuguese (Portugal). F1's own account page manages its own
translations; the Mac supplies the matching language through F1's existing
`user-language` preference in the ephemeral browser store before page scripts
initialize. F1 currently uses its own regional variants for Spanish and Portuguese.
The app's injected status uses the app translation, encoded as JSON so translated
quotes, backslashes and line breaks cannot break the verification script.

Validation: **88 core tests** and **46 native Mac checks** pass. Native tests cover
all six injected translations/language preferences, escaping and origin isolation.
Mac and tvOS simulator builds pass, and `verify-localizations.py --app` confirms
all six compiled F1Core translation tables match the catalog in both apps. The
checker also rejects missing keys and hard-coded login labels/status messages.
The isolated Mac test app now packages the shared resource bundle, matching the
production apps. No authenticated sign-in was needed for this localization audit.
