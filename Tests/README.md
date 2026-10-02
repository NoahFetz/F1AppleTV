# Local validation guide

Use a full Xcode installation selected through `DEVELOPER_DIR` or `xcode-select`.
Run commands from the repository root. The suites use public catalog fixtures,
synthetic account/DRM responses and local unencrypted media; they do not need your
F1 TV credentials.

| Check | Command |
| --- | --- |
| Backend, authentication and FairPlay ownership | `bash Tests/run-backend-tests.sh` |
| Catalog, presentation, settings, diagnostics and preview pool | `bash Tests/run-catalog-tests.sh` |
| FairPlay request format | `bash Tests/run-fairplay-tests.sh` |
| Playlist, rendition selection and preview playlists | `bash Tests/run-resolution-tests.sh` |
| Local AVFoundation playback (requires ffmpeg and Python 3) | `bash Tests/run-resolution-tests.sh --playback` |
| Credential migration and storage doubles | `bash Tests/Credentials/run.sh` |
| String catalog | `python3 Tests/verify-localizations.py` |
| Actual Alamofire transport with mocked responses | `F1_ALAMOFIRE_SOURCE=/path/to/resolved/Alamofire bash Tests/run-transport-tests.sh` |

The transport check needs an existing resolved Alamofire checkout; it does not
download packages. Signing is needed for simulator account/Keychain checks.
DRM-protected playback requires a physical Apple TV. Automated and simulator
results do not establish authenticated hardware compatibility.

The dated notes below record validation of individual changes. Later notes
supersede earlier test counts, warning counts and implementation details; the
FairPlay content-key migration is the latest DRM implementation described here.

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
