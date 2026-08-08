# Native integration and compatibility

The Unity package exposes a version-neutral C# API while pinning known native contracts behind its
platform bridges.

| Platform | Native Core dependency | Minimum target | Build requirement |
| --- | --- | --- | --- |
| Android | `io.kenkai.android.sdk:core:1.0.10` | API 21 | compile SDK 33 or newer; Java 8 bytecode |
| iOS | `KenkaiSDKCore` exact `1.0.10` | iOS 13.0 device; iOS 14.0 arm64 Simulator | Xcode 13.3 or newer |

Only the Core module is added. The Android build hook adds the pinned Maven dependency plus
AndroidX Process Lifecycle and Startup. The iOS build hook copies a bundled, Core-only local Swift
package containing the exact `1.0.10` Core sources and MMKV binary. It does not resolve a floating
remote range, and it works without network access during the Xcode build.

Maintainers must build the Android facade AAR with JDK 17. Java 21 and newer add unnamed synthetic
bridge-method metadata that the D8 version bundled with Unity 2021.3 cannot read. The emitted
classes remain Java 8 bytecode for host-project compatibility.

The bundled MMKV device and x86_64 Simulator binaries support deployment targets below iOS 14,
but its arm64 Simulator slice was built with iOS 14.0 as its minimum. This does not change the iOS
13 device minimum; Apple Silicon Simulator validation must use an iOS 14 or newer runtime.

## Why the settings asset is build-time configuration

Automatic app-open, resume, background, and close events begin before a Unity scene can run. The
build hooks copy `Assets/Resources/CausalFoundrySettings.asset` into Android manifest metadata and
the iOS Info.plist. A native bootstrap can then configure Core at the real application lifecycle
boundary. Calling `Initialize` from C# attaches the managed callback bridge and is idempotent.

If the key is supplied only from scene code, identity, user- and other-catalog, Track, and action
APIs still initialize, but the native SDK may have missed the first launch event. Use runtime-only
initialization for local experiments, not production telemetry.

When consent is undecided at launch, configure `PauseSdk = true` in the settings asset so the
native early bootstrap starts with event logging paused. After initialization, call
`CFSDK.SetPaused(false)` only when the host application is allowed to resume event
logging. On iOS the pause stops the foreground action listener, but manual action fetches,
previously registered background work, and uploads of already queued events are not all gated by
that flag.

Android Core `1.0.10` can continue periodic network action fetches scheduled before pause, and its
connectivity receiver can recreate that work. `SetPaused` is therefore not a network-silence
boundary on either platform. If the application's consent policy forbids all Kenkai network
activity, disable **Auto Initialize**, omit early native bootstrap, and call `Initialize` only after
consent is granted. Pausing does not revoke an operating-system notification token or replace the
host's consent, deletion, and data-subject-request flows.

## Notification permission

Call
`CFSDK.RequestNotificationPermission(Action<CFResult<NotificationPermissionStatus>> completion = null)`
from a user-initiated permission flow. It is independent of SDK initialization; a successful call
completes with `Authorized`, `Denied`, or `NotRequired`.

On Android 8.0 and newer, Android Core `1.0.10` owns `CF_NOTIFICATION_CHANNEL`. Core evaluates
app-level notification permission independently of whether that channel exists, treats a missing
channel as available for lazy creation, and blocks notification delivery when the user explicitly
disables the channel. The Unity permission API does not pre-register or alter Core's channel. Apps
should still target API 33 or newer so the host controls when the notification prompt appears.

On Android 13 and newer, the method opens the operating-system prompt; the package's merged manifest
declares `android.permission.POST_NOTIFICATIONS`. Android 12 and older returns `NotRequired`. On iOS,
it requests alert, badge, and sound authorization. Apple does not require an Info.plist
usage-description key for this prompt.

The current Kenkai notification actions are local, so the package does not add an APNs entitlement
or remote-notification background mode. Applications that add remote push remain responsible for
their own capabilities, registration, and token lifecycle.

## Host-app responsibilities

- Present notification permission from an appropriate user context; do not trigger the operating-
  system prompt automatically at startup.
- Review user consent, privacy disclosures, retention, and store data-safety declarations for the
  events and metadata your application sends.
- Review generated Xcode package embedding and the app's privacy manifest before App Store release.
- On iOS, the launch shim chains the application's delegate methods so Core can initialize before
  `didFinishLaunching` completes. If another native plugin also swizzles `UIApplication.setDelegate:`
  or `application:didFinishLaunchingWithOptions:`, test both initialization orders in the final app.
- The iOS launch shim installs the process-wide `UNUserNotificationCenter` delegate after the
  host's `didFinishLaunching` callback and forwards to a delegate already present at that time.
  If another library replaces the delegate later or owns the native action-click handler, test both
  initialization orders and restore the forwarding or delegate coexistence the application needs.

Native action-fetch APIs do not expose equivalent failures on both platforms. Android may report an
empty list for a native failure; on either platform the bridge fails a fetch after 60 seconds if the
native completion never arrives.
