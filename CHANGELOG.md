# Changelog

## Unreleased

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
