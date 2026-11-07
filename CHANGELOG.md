# Changelog

## 1.0.15 - 2026-11-07

The package version jumps from `1.0.11` to `1.0.15` to match the Android and iOS Core releases it
bundles and pins.

- Fixed an iOS crash when the app moved to the background after **Auto Initialize** was disabled
  and `CFSDK.Initialize` was called later (or never). The launch shim now registers the bundled iOS
  Core SDK's background tasks during launch regardless of **Auto Initialize**, and Core no longer
  submits background tasks whose handlers were not registered.
- Updated the bundled iOS Core SDK to `1.0.15` with the matching upstream fixes: events that fire
  before initialization are dropped instead of crashing, background tasks that iOS runs before
  initialization finish without doing work, and release builds no longer trap on an empty SDK key,
  a missing vendor identifier, an invalid API base URL, a failed MMKV open, a malformed
  `MinimumOSVersion`, or an event object decoded from JSON.
- Updated the Android Core SDK dependency to `1.0.15`: events and catalog items logged during an
  in-flight upload are no longer lost, a failed catalog upload keeps its items for the next attempt,
  a failed upload no longer re-queues events that were already stored (which doubled the pending
  queue on every failed attempt), and a quick switch away and back to the app no longer logs an
  `app background` event.
- With **Auto Initialize** disabled, in-app messages and `CFSDK.FetchActions` now work right after
  a late `CFSDK.Initialize` (Core treats the app as open when initialized in the foreground),
  `FetchActions` completes with an empty result instead of timing out when Core's request fails, and
  release builds no longer crash on native validation errors raised before initialization.
- Added `CFSDK.LogActionResponse(action, response, details)` and the `ActionResponses` values, so a
  game that renders fetched actions itself can report shown, open, discard, block, error, or
  expired. The Android facade now requires Android Core `1.0.15`, and the generated Gradle
  dependency is pinned to it.
- After a late `CFSDK.Initialize` on iOS, the app-open event is logged and stored events are uploaded
  immediately instead of waiting for a background task or the next foreground, and every return to
  the foreground uploads stored events (iOS 26 did not always deliver the activation callback Core
  relied on).
- Fixed iOS events and catalog items logged during an in-flight upload being lost: a successful
  upload now removes only the items it sent.
- Fixed iOS event uploads when **Allow Anonymous Users** is disabled: events are now uploaded for
  the identified user, and events logged before `Identify` are stored instead of lost.
- Fixed Android builds keeping **Auto Initialize** on after it was disabled: Unity reuses the
  generated manifest between builds, and the SDK key metadata written by an earlier build was left
  in place. The build hook now removes it.
- Documented Android **Minimum API Level** 24 and added a build warning below it: Unity 2021.3's
  bundled D8 fails with a `StackOverflowError` while desugaring Core's Kotlin dependencies for
  lower API levels (this also affects `1.0.11`).

## 1.0.11 - 2026-11-01

- Updated the bundled iOS Core SDK to `1.0.11`. It no longer shows the "Enable Background App
  Refresh" alert on every launch when Background App Refresh is off, always registers its
  background tasks at launch, ignores repeated `Kenkai.configure()` calls, and no longer crashes
  debug builds on network failures.
- Updated the Android Core SDK dependency to `1.0.11`, a version-alignment release with no
  functional changes on Android.

## 1.0.10 - 2026-08-08

- Changed the Unity package license to the GNU Affero General Public License v3.0 only.

## 1.0.7 - 2026-08-08

- Added a native-shaped `CFSDK.FetchActions` overload that accepts action type, render method,
  delivery mode, action attributes, and completion directly.

## 1.0.6 - 2026-08-07

- Renamed managed `CausalFoundry*` class identifiers to their shorter `CF*` equivalents. This is a
  breaking source-level API change; the `CausalFoundry.Unity` namespace and assembly remain stable.
- Added `CFSDK.LogOtherCatalog` for custom Core catalogs with non-empty metadata on Android and iOS.
- Added the installed UPM package version as `meta.unity_version` on Identify and custom Track
  events without mutating caller metadata.
- Added `InitializeAndIdentify` to load package settings and run initialization, identity, and an
  optional non-empty user-catalog update in sequence.
- Added `FetchCustomActions` for the documented one-off, in-app-component custom action query.
- Updated the bundled iOS Core SDK to `1.0.10`, including custom-catalog support and duplicate
  in-app action deduplication.
- Updated the Android Core SDK dependency to `1.0.10`, including its edge-to-edge in-app message and
  notification-channel state fixes.
- Removed the redundant Unity Android safe-area layout injection and notification-channel
  pre-registration shims now owned by Core.

## 1.0.5 - 2026-08-07

- Kept Android in-app messages below the safe top inset when Unity hides the status bar in
  immersive fullscreen mode.
- Added Android 11+ hidden-system-bar inset handling and a stable-inset fallback for older Android
  versions.

## 1.0.4 - 2026-08-07

- Rebuilt the Android facade AAR with JDK 17 so Unity 2021.3's D8 can dex its Kotlin callback
  bridges without an internal `NullPointerException`.
- Enforced JDK 17 in the native Android build script and added a regression check for the
  incompatible bridge-method metadata emitted by newer Java compilers.

## 1.0.3 - 2026-08-07

- Registered the Android Core notification channel before permission-dependent Core work so
  notification access is not misreported as blocked when the host game has another channel.

## 1.0.2 - 2026-08-06

- Kept Android in-app messages below status bars and display cutouts in fullscreen Unity players.

## 1.0.1 - 2026-08-06

- Finalized the UPM package identity as `io.kenkai.upm.sdk` ahead of the first public release.

## 1.0.0 - 2026-08-06

- Prepared the initial stable UPM package.
- Set the minimum supported Unity editor version to Unity 2021.3 LTS.
- Added the stable managed `CausalFoundrySDK` facade.
- Added settings-based early initialization for Android and iOS.
- Added app-target embedding and signing of the correct MMKV XCFramework slice on iOS.
- Added Identify, Track, action fetching, in-app messages, and action-open callbacks.
- Added portable Core user catalog dimensions through `LogUserCatalog` on Android and iOS.
- Added typed results/errors, action models, and an AOT-safe deterministic JSON codec.
- Added EditMode tests for validation, serialization, native exception isolation, and action parsing.
- Added runtime pause/resume for consent changes through `CausalFoundrySDK.SetPaused`.
- Added explicit notification permission through `CausalFoundrySDK.RequestNotificationPermission`,
  including Android 13 runtime permission and iOS alert, badge, and sound authorization.
- Updated the bundled iOS Core SDK to `1.0.9`, including its light-mode and body-text-color
  in-app message presentation fixes.
- Updated the Android Core SDK dependency to `1.0.9`, including its light-theme and text-color
  in-app message presentation fixes.
- Installed the iOS notification delegate during application launch, after the host launch callback,
  and forward callbacks to a delegate that was already registered by the host application.
- Documented that native pause is event suppression, not a zero-network consent boundary.
- Added domain-reload-safe managed state reset and an assembly-isolated sample.
- Added Git installation, package validation, and release documentation.
- Made Editor and non-mobile calls safe no-ops while keeping Android/iOS bridge selection internal.
