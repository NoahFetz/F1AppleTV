# Backend client

`AppServices` is the scene composition root. It constructs one Alamofire transport,
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
  exchange or deliver licenses. The resource loader now only serves filtered
  HLS playlists. Thumbnail generation receives the same injected FairPlay service
  but owns a separate key session. tvOS Simulator skips native FairPlay session
  construction, which the platform rejects with an Objective-C exception.

Only catalog and certificate GETs retry once for transient connectivity or
502/503/504. Login, logout, license and play-time POSTs are not replayed automatically.
Controllers own final failure reporting, inline state, Retry and alerts. Expected
cancellation and superseded completions are ignored. Diagnostics store safe fields
only, with no credentials, headers, response bodies, signed URLs or DRM data.

See Tests/README.md for fixture, transport, storage, playback and simulator checks.
Authenticated physical Apple TV checks remain separate from those results.
