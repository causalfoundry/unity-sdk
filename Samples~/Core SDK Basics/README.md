# Core SDK Basics sample

1. Import this sample from the package's **Samples** tab in Unity Package Manager.
2. Run **Tools > Causal Foundry > Create or Select SDK Settings**, enter the raw SDK key, and
   disable **Auto Show In App Messages** when the game will fetch and present actions manually.
3. Add `CFCoreExample` to a GameObject in your first scene.
4. Enter Play mode in the Editor or an Android/iOS player build. Editor calls are safe no-ops;
   Android and iOS builds route to their matching native Core SDK internally.

The component initializes the Core SDK, uses an Inspector-supplied player ID or creates a stable
per-install ID, logs `country = Spain` and
`role = game_user` as Core user catalog dimensions, and tracks `unity_sample_started`. Its public
`RequestNotificationPermission`, `FetchCustomActions`, and `ShowDefaultInAppMessage` methods can be
wired to UI buttons. Present the permission button only after explaining why notifications are
useful. Change `Enable Debug Mode` off before producing a release build.
