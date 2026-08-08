# Causal Foundry Kenkai SDK for Unity

Unity Package Manager wrapper for the Causal Foundry Kenkai Core SDK on Android and iOS.

- Unity package: `io.kenkai.upm.sdk` version `1.0.7`
- Unity: 2021.3 LTS or newer
- Android: min SDK 21 and compile SDK 33 or newer
- iOS: iOS 13.0 or newer and Xcode 13.3 or newer

The public API uses the `CausalFoundry.Unity` namespace and the `CFSDK` facade. The Unity Editor
uses a safe no-op bridge, so test actual event delivery and action responses in an Android or iOS
player build.

## 1. Add the SDK with Unity Package Manager

First, open the [Unity SDK GitHub repository](https://github.com/causalfoundry/unity-sdk) and find
the version you want to install under its releases or tags.

In Unity, open **Window > Package Manager**, click **+**, choose **Add package from git URL**, and
enter the URL below after replacing `<RELEASE_TAG>` with that version tag:

```text
https://github.com/causalfoundry/unity-sdk.git#<RELEASE_TAG>
```

Alternatively, add the package to the `dependencies` object in
`Packages/manifest.json`:

```json
{
  "dependencies": {
    "io.kenkai.upm.sdk": "https://github.com/causalfoundry/unity-sdk.git#<RELEASE_TAG>"
  }
}
```

Pin production projects to a release tag or full commit SHA. The repository root is the UPM package,
so the Git URL does not need a `?path=` query.

Next, run **Tools > Causal Foundry > Create or Select SDK Settings**. In the selected settings
asset:

1. Enter the raw SDK key from the Kenkai Platform.
2. Keep **Auto Initialize** enabled for the normal integration.

Unity does not automatically modify a consumer project's custom Assembly Definitions when the
package is installed. If the game uses a custom Assembly Definition:

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

Consumer scripts normally need:

```csharp
using System.Collections.Generic;
using CausalFoundry.Unity;
```

## 2. Initialize the SDK and identify the user

`InitializeAndIdentify` loads the settings asset, initializes the SDK, identifies the supplied
user, and optionally logs user-catalog dimensions:

```csharp
using System.Collections.Generic;
using CausalFoundry.Unity;
using UnityEngine;

string userId = "YOUR_STABLE_USER_ID";
IdentityAction identityAction = IdentityAction.Login;

IDictionary<string, string> userCatalog =
    new Dictionary<string, string>
    {
        { "account_type", "game_user" },
        { "region", "europe" }
    };

CFSDK.InitializeAndIdentify(
    userId,
    identityAction,
    userCatalog,
    result =>
    {
        if (!result.IsSuccess)
        {
            Debug.LogError("InitializeAndIdentify failed: " + result.Error);
            return;
        }

        Debug.Log("SDK initialized and user identified.");

        CFSDK.RequestNotificationPermission(permissionResult =>
        {
            if (!permissionResult.IsSuccess)
            {
                Debug.LogError(
                    "Notification permission request failed: " +
                    permissionResult.Error);
                return;
            }

            Debug.Log(
                "Notification permission: " +
                permissionResult.Value);
        });
    });
```

Use a stable ID from the game's account system. Use `IdentityAction.Register` when introducing a
new identity for the first time and `IdentityAction.Login` for later authenticated sessions. Do
not ship one shared literal user ID.

`userCatalog` is optional. Pass `null` or an empty `Dictionary<string, string>` to skip the
user-catalog step:

```csharp
CFSDK.InitializeAndIdentify(
    userId,
    IdentityAction.Login,
    null,
    result =>
    {
        if (!result.IsSuccess)
            Debug.LogError(result.Error);
    });
```

Call this function from Unity's main thread. If **Auto Initialize** already started initialization,
the function joins that matching initialization instead of starting a second SDK instance.
Every Identify event automatically includes `meta.unity_version` with the installed UPM package
version.

### Notification permission

Android 13 and newer and iOS require notification permission before notification-based actions can
be displayed. Request it after successful SDK initialization, as shown above, and preferably after
explaining to the user why notifications are useful. If the user denies permission, notification
actions cannot be shown.

On Android, the package already declares `POST_NOTIFICATIONS`, so no manual manifest change is
needed; Android 12 and older returns `NotificationPermissionStatus.NotRequired`. On iOS, the SDK
requests alert, badge, and sound permission. This permission is not required for custom actions or
in-app messages.

## 3. Track custom events

Call `Track` after a successful identity callback when the event must be associated with that
user:

```csharp
CFSDK.Track(
    "level_completed",
    new TrackOptions
    {
        Property = "level_7",
        Metadata = new Dictionary<string, object>
        {
            { "score", 1200 },
            { "perfect", true },
            { "attempts", 2 }
        }
    },
    result =>
    {
        if (!result.IsSuccess)
            Debug.LogError("Track failed: " + result.Error);
    });
```

The event name is trimmed, converted to lowercase, and has spaces replaced with underscores.
Built-in SDK event names cannot be used as custom event names. Metadata may contain JSON-compatible
strings, booleans, finite numbers, lists, dictionaries, and null values.

A successful callback means the native SDK accepted or dispatched the event; it is not a
server-delivery acknowledgement.

Every custom Track event automatically includes `meta.unity_version` with the installed UPM
package version. If caller metadata contains the same key, the SDK-owned value is used in the
outbound copy without modifying the caller's dictionary.

## 4. Log a custom (Other) Catalog

Use `LogOtherCatalog` to attach reusable dimensions to a custom catalog subject. This logs catalog
data; use `Track` from the previous section for custom events.

```csharp
string subjectId = "household_123";
string catalogName = "household";

IDictionary<string, object> metadata =
    new Dictionary<string, object>
    {
        { "head_household_id", "user_456" },
        { "members", 4 },
        { "is_approved", true }
    };

CFSDK.LogOtherCatalog(
    subjectId,
    catalogName,
    metadata,
    result =>
    {
        if (!result.IsSuccess)
            Debug.LogError("Other Catalog failed: " + result.Error);
    });
```

`subjectId` and `catalogName` must be non-empty. `metadata` is required and must contain at
least one JSON-compatible value. Catalog names are normalized to snake case, and names reserved by
the SDK's built-in catalogs are rejected.

## 5. Fetch custom actions

Custom actions are fetched and rendered manually by the game. Before the SDK initializes:

1. Run **Tools > Causal Foundry > Create or Select SDK Settings**.
2. In the settings Inspector, disable **Auto Show In App Messages**.
3. Save the settings asset.
4. Restart Play mode, or rebuild and relaunch the mobile player, so the setting is applied during
   initialization.

Then call `FetchActions` after initialization succeeds, providing the native action parameters
directly:

```csharp
CFSDK.FetchActions(
    invActionType: ActionTypes.Custom,
    actionRenderMethodType: ActionRenderMethods.InAppComponent,
    deliveryMode: ActionDeliveryModes.OneOff,
    actionAttributes: new Dictionary<string, string>
    {
        { "hello", "world" }
    },
    completion: result =>
    {
        if (!result.IsSuccess)
        {
            Debug.LogError("FetchActions failed: " + result.Error);
            return;
        }

        foreach (CFAction action in result.Value)
        {
            string title = action.Payload?.Content?.Title;
            string body = action.Payload?.Content?.Body;

            // Render the returned content with the game's Unity UI.
            Debug.Log(title + ": " + body);
        }
    });
```

### Fetch action parameter values

| Parameter | Unity value | Native value | Notes |
| --- | --- | --- | --- |
| `invActionType` | `ActionTypes.Message` | `message` | Message actions such as notifications or in-app messages. |
| `invActionType` | `ActionTypes.Custom` | `custom` | Recommended cross-platform value for custom UI actions; maps to `.UIComponent` on iOS. |
| `invActionType` | `ActionTypes.UiComponent` | `ui-component` | iOS Core alias for UI-component actions; prefer `Custom` for cross-platform calls. |
| `actionRenderMethodType` | `ActionRenderMethods.PushNotification` | `push_notification` | Render as a notification. |
| `actionRenderMethodType` | `ActionRenderMethods.InAppMessage` | `in_app_message` | Render as a native in-app message. |
| `actionRenderMethodType` | `ActionRenderMethods.InAppComponent` | `in_app_component` | Return content for the game's custom Unity UI. |
| `deliveryMode` | `ActionDeliveryModes.OneOff` | `one-off` | Return an action once. |
| `deliveryMode` | `ActionDeliveryModes.Cached` | `cached` | Return matching cached actions until they expire. |
| `actionAttributes` | `null` | `{}` | Fetch without attribute filters. |
| `actionAttributes` | `new Dictionary<string, string>()` | `{}` | Also fetches without attribute filters. |
| `actionAttributes` | Populated `Dictionary<string, string>` | String map | Filters using the attributes configured for the action. |

Pass `null` or an empty `Dictionary<string, string>` as `actionAttributes` when no action
filters are needed. Attributes are a key/value map, so use an empty dictionary rather than a C#
`List`. Every key and value must be a string.

The common cross-platform custom-action combination is:

- `ActionTypes.Custom` → `InvActionType.Custom`
- `ActionRenderMethods.InAppComponent` → `ActionRenderMethodType.InAppComponent`
- `ActionDeliveryModes.OneOff` → `ActionDeliveryMode.OneOff`

The completion callback is required, and the returned data is never displayed automatically.
`FetchCustomActions(actionAttributes, completion)` remains available as the convenience shortcut
for the `custom`, `in_app_component`, `one-off` combination.

In the Unity Editor, valid calls complete as no-ops and custom-action fetches return an empty list.
Use an Android or iOS player build to verify dashboard ingestion and real action payloads.

For platform build details and troubleshooting, see the
[installation guide](Documentation~/installation.md) and
[native integration notes](Documentation~/native-integration.md).
