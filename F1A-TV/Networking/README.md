# Backend client

`F1Core` owns the shared services, models and wire mapping used by tvOS and macOS.
`AppServices` is the tvOS scene composition root. It constructs one Alamofire transport,
API client, authentication actor, catalog service, playback service and FairPlay
service, then configures controllers through factories before their views load.
Tests can replace every service, the transport, credential store, challenge
provider and retry delay. No service singleton reads credentials or presents UI.

- `HTTPTransport` executes a URLRequest, validates HTTP status and returns bytes.
  The Alamofire implementation bridges task cancellation to the underlying request.
- `APIEndpoints` owns endpoint paths, methods, providers and required headers.
  Catalog destinations retain their query encoding and use WEB_HLS. Playback uses
  BIG_SCREEN_HLS. Artwork and HLS loading retain their independent existing paths.
- `Wire` contains Decodable response DTOs and Encodable request bodies. Envelopes
  check resultCode before decoding resultObj. Catalog mapping isolates malformed
  siblings and records only safe reason codes and section/item indices.
- `Models` contains Foundation-only app values, explicit catalog content/actions,
  dates, stable identities, channels, profiles and runtime-only entitlements.
  Presentation owns localization, headings, driver names and sorting.
- `F1AuthService` serializes account state, shares a refresh task and merges headers.
  Eligible requests refresh on 401 and replay once. Generic 403, decoding failures,
  reporting and unrelated failures do not refresh. Authentication generations and
  queued credential writes prevent a late completion from restoring logged-out
  or superseded credentials.
- tvOS uses `F1DeviceAuthService` for phone sign-in through F1's public TV client
  and RFC 8628 device authorization endpoints. `LoginViewController` displays the
  provider's QR URL, address and code, with a countdown, cancellation and new-code
  action. Polling respects the provider interval, pending/slow-down responses,
  expiry and backoff. OAuth error bodies stay inside the service; credentials and
  responses are not included in diagnostics.
- `KeychainDeviceSessionStore` saves the rotating refresh credential and F1
  playback session in a separate Keychain record. Existing legacy registrations
  remain usable. F1's initial OAuth token contains a separate subscription JWT;
  refresh responses currently omit it. The service preserves that JWT only until
  its original expiry while rotating the OAuth refresh credential. If renewal
  does not reissue an expired playback JWT, the stale session is cleared and the
  user must pair again. The observed lifetimes were one hour for OAuth access and
  four days for playback in the TV flow.
- macOS uses the same service as `F1OAuthAuthService`. F1's web client accepts
  authorization-code/PKCE sign-in but omits refresh credentials, including when
  offline access is requested. `MacBrowserLogin` therefore opens the provider's
  `verification_uri_complete` in an ephemeral browser sheet and polls the shared
  device grant. The user signs in locally;
  only the matching, prefilled verification is submitted automatically. No phone,
  QR scan, manual code entry or extra confirmation click is needed. Each attempt
  gets a fresh nonpersistent browser, and cancellation/retry invalidates the
  previous attempt.
  The Mac observes F1's completion route and then requests tokens immediately,
  instead of polling during credential entry. Pending/slow-down responses retain
  the provider's interval rules. If no completion is observed within one minute,
  regular polling provides a fallback. The sheet closes only after Keychain
  persistence, with a native finishing indicator while that request completes.
  `MacOAuthSessionStore` keeps the rotating refresh credential and playback token
  in the Mac Keychain. Older browser sessions remain available with an action to
  sign in again for OAuth renewal; sign-out also discards superseded sessions.
- `KeychainSessionStore` retains the existing service/key names and CoreData
  migration. The legacy registration structs under DataTransferObjects/Security
  are intentionally retained solely as the persisted serialization format;
  endpoint responses use AccountDTO and map into that storage format. Settings
  and language-specific menu caches are unchanged.
- `F1FairPlayService` lazily shares and caches certificate data. A failed fetch can
  be attempted later. Licenses retain the established SPC body, headers, asset-ID
  normalization and CKC decoding; entitlement and license data are never persisted.
  `FairPlayKeyLoader` owns cancellable key tasks. The AVFoundation adapter uses
  one ephemeral `AVContentKeySession` per player/preview, registers assets before
  loading, generates SPC asynchronously, and delivers decoded CKC through
  `AVContentKeyResponse`. Key renewal uses the same license flow. Session
  invalidation cancels pending work; late and duplicate SPC callbacks cannot
  exchange or deliver licenses. The resource loader serves filtered HLS playlists
  and marks `skd` requests (including renewals) with
  `AVStreamingKeyDeliveryContentKeyType` before finishing them. This hands key
  loading to the native session; it does not generate SPC or deliver CKC through
  the resource loader. Rejecting those requests prevents the native session from
  loading the key. Thumbnail generation receives the same injected FairPlay service
  but owns a separate key session. tvOS Simulator skips native FairPlay session
  construction, which the platform rejects with an Objective-C exception.

Only catalog and certificate GETs retry once for transient connectivity or
502/503/504. Login, logout, license and play-time POSTs are not replayed automatically.
Device-token polling follows the separate OAuth interval/backoff rules above.
Controllers own final failure reporting, inline state, Retry and alerts. FairPlayer
reports presentation errors through an injected callback; platform code owns its
resolution menu. The tvOS adapters preserve existing alert behavior. Expected
cancellation and superseded completions are ignored. Diagnostics store safe fields
only, with no credentials, headers, response bodies, signed URLs or DRM data.

See Tests/README.md for fixture, transport, storage, playback and simulator checks.
Authenticated physical Apple TV checks remain separate from those results.
