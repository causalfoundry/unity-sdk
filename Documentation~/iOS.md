# iOS integration

The Unity package links only the Causal Foundry Core product. During an iOS build it:

- copies the bundled Core-only `KenkaiSDKCore` `1.0.10` local Swift package into the generated
  Xcode project;
- compiles the Swift/C ABI bridge into `UnityFramework`;
- selects the correct MMKV device or simulator slice and embeds it in the application target;
- sets Swift language mode 5 and raises targets below iOS 13.0 to iOS 13.0;
- merges `fetch` and `processing` into `UIBackgroundModes`; and
- merges `io.kenkai.ingestAppEvents` and `io.kenkai.fetchActions` into
  `BGTaskSchedulerPermittedIdentifiers`.

Those identifiers match the pinned `1.0.10` Core source. Older setup pages may still show the legacy
`ai.kenkai.fetchNudges` identifier, which that pinned release does not register.

No CocoaPods installation, remote Swift-package download, or network access is required for the
iOS Core dependency. The bundled package contains only the Core sources and their MMKV binary;
non-Core Causal Foundry modules are not included.

The bundled MMKV arm64 Simulator slice has an iOS 14.0 deployment minimum. Device builds retain the
iOS 13.0 package minimum, while Apple Silicon Simulator tests require an iOS 14 or newer runtime.

## Capture the first app-open event

Create one `CFSettings` asset at
`Assets/Resources/CausalFoundrySettings.asset`, provide the SDK key, and leave **Auto Initialize**
enabled. The iOS postprocessor writes those settings into the built app's `Info.plist`. A native
launch shim configures Core before UIKit finishes launching, so the native lifecycle observer sees
the first app-open event and registers its background tasks on time.

Calling `CFSDK.Initialize` at runtime still works without the asset, but initialization
then occurs after the earliest iOS launch callbacks and cannot recover that first app-open event.

## Notification permission

Call `CFSDK.RequestNotificationPermission` from a user-initiated permission flow. It
requests alert, badge, and sound authorization and returns `NotificationPermissionStatus.Authorized`
or `Denied`. The request is independent of SDK initialization and needs no Info.plist
usage-description key.

The package does not add an APNs entitlement because the current Kenkai notification actions are
local. Kenkai's launch shim installs its process-wide `UNUserNotificationCenter` delegate after the
host's `didFinishLaunching` callback and forwards to a delegate already present at that time. If the
host application or another plugin replaces the delegate later, test both initialization orders and
restore the required coexistence.

## Native behavior retained

Identify and Track completions mean that Core accepted the event locally. User- and other-catalog
completions mean their validated models were dispatched to Core; the pinned SDK performs the final
catalog update asynchronously. Upload timing remains owned by the native SDK. Action fetches keep
the native response JSON intact and fail with a 60-second timeout if Core never invokes its result callback.
Native action-open attributes are forwarded as one JSON object and buffered across cold managed
startup.

`CFSDK.SetPaused` updates Core's runtime pause flag without rebuilding its initialization
configuration and stops the foreground action listener. Manual action fetches, previously
registered background work, and uploads of already queued events are not all gated by that flag,
so pause is not a network-silence boundary. If consent requires no Kenkai network activity, disable
Auto Initialize and delay `Initialize` and all other SDK calls until consent is granted.

`ActionScreens.Default` is the empty wire value and maps to the iOS Core SDK's `.None` screen.

## Build conflicts

The package intentionally bundles Core `1.0.10`. If another postprocessor adds the remote
`CausalFoundry/ios-sdk` repository, the iOS build fails with a diagnostic rather than linking two
copies of the same Swift module. Remove the remote reference; this wrapper's local Core package is
the dependency used by the generated Xcode project.
