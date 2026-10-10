# F1Core

Shared Swift package used by F1A-TV and F1A-Mac. It owns catalog decoding and
mapping, service contracts, authentication/refresh, FairPlay, HLS rendition
selection, playback preferences, feed matching, diagnostics and translations.
It has no UIKit, SwiftUI or AppKit dependency.

Platform applications own navigation, windows, credential/settings storage and
browser challenge preparation. The tvOS composition root retains its Alamofire
transport and CoreData-to-Keychain migration; macOS uses URLSession and a
separate Keychain service. Both use the same API client and authorization policy.
Registration nickname and device construction are injected into F1AuthService;
its defaults preserve the original tvOS request.

FairPlayer reports presentation failures through `onPlaybackError`. The platform
must set that callback before preparing playback. The player still records safe
diagnostics and owns its native FairPlay session, rendition switches and cleanup.
Resolution menus belong to the application. HLSResolutionPlaylist can filter
SDR versus HLG/PQ variants with resolution. FairPlayer's optional dynamic-range
selection reuses its quality-switch restoration and rollback. Existing callers
keep automatic/native range selection unless they explicitly request a range.

The package exposes AVFoundation playback helpers. LinkedPlaybackCoordinator
accepts platform player adapters and routes shared transport operations. The macOS
session supplies a two-second drift timer, while each window owns local audio and
media selection. Existing tvOS controllers retain their behavior and use the
shared live-seek helpers.

`Resources/Localizable.xcstrings` is the translation source of truth. Use the
shared `localizedString` extension, which resolves the package resource bundle.

Run package tests with `swift test --package-path F1Core` from the repository root.
See ../Tests/README.md for fixture, native playback and application checks.

`PlaybackThumbnailProvider` is shared by the tvOS scrub overlay and macOS
timeline. Both default to timestamp-only scrubbing; `PlayerSettings.scrubPreviews`
opts into frames. It decodes HLS image renditions and tiles and caches nearby images.
I-frame renditions use a separate paused, muted FairPlayer and AVPlayerLayer,
preferring the smallest SDR track. FairPlay frames remain in native rendering;
they are not extracted as CGImages. Each application hosts the returned image
or video layer. Requests coalesce while preparation/seeking is in progress.
Program dates align dated streams; replay positions are clamped to available
ranges. Cancel invalidates pending deliveries and releases the native preview
player and content-key session. There is no automatic scrub-player warm-up.
AVAssetImageGenerator is reserved for the
optional unprotected-video fallback.
