# Installation

Follow these steps for a new Unity project. The package lives at the root of the standalone
`causalfoundry/unity-sdk` repository, so its Git URL does not need a UPM `?path=` query.

## 1. Confirm the target versions

- Unity 2021.3 LTS or newer.
- Android min SDK 21 and compile SDK 33 or newer. Target API 33 or newer when shipping on Android
  13+ so the application controls notification permission prompt timing.
- iOS 13.0 or newer and Xcode 13.3 or newer.

## 2. Install a pinned Git revision

In Unity, open **Window > Package Manager**, click **+**, choose **Add package from git URL**, and
enter:

```text
https://github.com/causalfoundry/unity-sdk.git#v1.0.10
```

Or add the same dependency to the consuming project's `Packages/manifest.json`:

```json
{
  "dependencies": {
    "io.kenkai.upm.sdk": "https://github.com/causalfoundry/unity-sdk.git#v1.0.10"
  }
}
```

Replace `v1.0.10` with the required published version. Pin a release tag or full commit SHA for
production builds so resolution is reproducible. A branch such as `#main` can move without a
consumer manifest change and is appropriate only for testing unreleased SDK changes.

## 3. Use a local checkout when developing the SDK

Clone the repository outside the consumer project's `Assets` folder. In Package Manager, choose
**Add package from disk** and select the checkout's root `package.json`. Unity records a local
`file:` dependency in the consumer manifest.

Alternatively, place the checkout directly at `Packages/io.kenkai.upm.sdk` in the consumer
project. Unity then treats the folder as an embedded package. Do not use the embedded-package
layout for a production dependency unless the SDK source is intentionally vendored with the game.

## 4. Create the settings asset

1. Run **Tools > Causal Foundry > Create or Select SDK Settings**.
2. Enter a development SDK key from the Kenkai Platform. A pasted `Bearer ` prefix is
   accepted and removed.
3. Confirm that Unity created `Assets/Resources/CausalFoundrySettings.asset`.
4. Leave **Auto Initialize** enabled for the standard mobile integration. This lets native startup
   happen early enough to observe the application launch lifecycle.
5. Review the remaining defaults, then disable **Enable Debug Mode** before a production release.

`CFSettings` is the project-wide configuration read by both the Unity runtime and the Android and
iOS build hooks. Do not attach it to a GameObject or add it to a scene. The SDK loads it from
`Resources`, while the build hooks use it to configure native startup early enough to observe the
first application lifecycle events.

### CF Settings reference

| Inspector item | Default | Meaning | When to change it |
| --- | --- | --- | --- |
| **SDK Key** | Empty | Identifies the application to Kenkai. It is required for automatic initialization and for `CFSDK.InitializeAndIdentify(...)` when that method loads `CFSettings`. | Paste the raw key from the Kenkai Platform. Whitespace and an optional `Bearer ` prefix are removed automatically. |
| **Auto Initialize** | Enabled | Starts native Core at the application-launch boundary, before the first Unity scene, so it can observe first-launch and app-open lifecycle events. | Keep enabled for the standard integration. Disable when the application calls `CFSDK.Initialize(...)` itself or when consent forbids all Kenkai activity before opt-in. |
| **Allow Anonymous Users** | Enabled | Allows native Core to accept events before `Identify`; the device identifier represents the user until the application supplies a user ID. | Keep enabled for consistent Android and iOS behavior. Disable only when policy requires suppressing anonymous activity, then test the complete flow on both platforms. |
| **Update Immediately** | Disabled | Requests an immediate native upload attempt for accepted events instead of the normal upload schedule. Per-event options can override it where supported. | Enable only when lower-latency upload attempts are required. Success still confirms native acceptance, not server delivery. |
| **Auto Show In App Messages** | Enabled | Lets native Core automatically fetch and display eligible in-app messages during lifecycle processing. Manual action APIs remain available when this is disabled. | Disable before initialization when the game calls `CFSDK.FetchActions(...)` or `CFSDK.FetchCustomActions(...)` and renders the returned actions itself. |
| **Disable Auto Page Tracking** | Enabled | Prevents native Activity, Fragment, and view-controller transitions from being recorded as pages. These transitions usually do not represent Unity scenes or canvases. | Keep enabled for most Unity games. Disable only when meaningful native screens should be tracked automatically; record Unity navigation explicitly as custom events when needed. |
| **Pause SDK** | Disabled | Starts event ingestion and automatic foreground action work in a paused state. | Enable when initialization is allowed before consent but processing must wait, then call `CFSDK.SetPaused(false, ...)`. Pause is not a strict no-network boundary; for that requirement, disable **Auto Initialize** and make no SDK calls until opt-in. |
| **Enable Debug Mode** | Enabled | Enables native Core debug validation and diagnostic behavior. Invalid integration values can surface as native exceptions while this is enabled. | Keep enabled while integrating so configuration errors are visible, then disable it before production. It is separate from Unity's **Development Build** option. |

Initialization options are fixed when native Core starts. Changing the asset afterward does not
reconfigure that instance; use `CFSDK.SetPaused(...)` for runtime pause and resume changes.

Do not treat a value embedded in a Unity player as a secret. Use a development key while
integrating and follow the host application's release process for production configuration.

## 5. Reference the SDK from custom assemblies

Installing the package does not automatically modify custom Assembly Definitions in the consuming
project. If SDK calls live in an assembly defined by an `.asmdef` asset:

1. Select the consuming `.asmdef` asset in Unity's Project window.
2. In the Inspector, find **Assembly Definition References** and click **+**.
3. Select **CausalFoundry.Unity**.
4. Click **Apply**.

The resulting `.asmdef` references should include:

```json
"references": [
  "CausalFoundry.Unity"
]
```

Without this explicit reference, scripts in that custom assembly cannot resolve the
`CausalFoundry.Unity` namespace. Projects that use Unity's default `Assembly-CSharp` do not need
this step.

## 6. Choose the consent startup path

- When the SDK may start with the application, keep **Auto Initialize** enabled.
- When initialization is allowed but events must wait for consent, set **Pause SDK** in the asset
  and call `CFSDK.SetPaused(false, ...)` after consent.
- When consent requires no Kenkai network activity before opt-in, disable **Auto Initialize**,
  delay `CFSDK.Initialize(...)` until consent is granted, and do not call other SDK APIs
  first. Runtime pause is event suppression, not a strict network-silence boundary.

See the [package README](../README.md) for explicit initialization and pause examples.

## 7. Import the sample and check managed calls

1. Select the installed package in Package Manager and open its **Samples** tab.
2. Import **Core SDK Basics**.
3. Add `CFCoreExample` to a GameObject in the first scene.
4. Enter Play mode and exercise the sample controls.

The Editor intentionally uses a no-op bridge. It validates the managed lifecycle, argument
handling, and callbacks but does not send events. Native end-to-end behavior requires an Android or
iOS player build.

## 8. Verify both mobile integrations

1. Make an Android development build and confirm the generated manifest, min/compile SDK values,
   Gradle repositories, and pinned Kenkai Core dependency.
2. Run the Android build on a physical device and verify initialization, identify, user and other
   catalogs, Track, actions, notification permission, and notification delivery, including lazy
   creation of `CF_NOTIFICATION_CHANNEL`.
3. Export an iOS Xcode project and inspect the copied local Swift package, build settings,
   capabilities, background task identifiers, and Info.plist changes.
4. Build the iOS app for a device and simulator, then repeat the runtime smoke test on a physical
   device.
5. Review the [native integration guide](native-integration.md) and platform caveats before
   shipping.

## Package tests in a consumer project

Package tests are excluded from normal consumers. To run them, add the package ID to the test
project manifest's `testables` array:

```json
"testables": [
  "io.kenkai.upm.sdk"
]
```

Then run the EditMode suite named `CausalFoundry.Unity.Editor.Tests` in Unity Test Runner.
