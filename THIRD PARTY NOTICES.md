# Third-party notices

This package uses these native Core SDK distributions:

- Android: `io.kenkai.android.sdk:core:1.0.10`, resolved from Maven during the Android build.
- iOS: `KenkaiSDKCore` from `https://github.com/CausalFoundry/ios-sdk`, exact version `1.0.10`
  (`fb1390d9dff7bc054eb59b6df89a6778ad20ed45`), bundled as a Core-only local Swift package.

Both Causal Foundry/Kenkai native Core SDK distributions state that they are licensed under the
Apache License, Version 2.0. Their transitive dependency notices and licenses remain applicable to
the final mobile application and should be reviewed as part of the application's release process.

The bundled iOS package changes its Swift package manifest to exclude all non-Core products and
tests, and raises the declared minimum from iOS 12 to iOS 13 to match the APIs used by Core
`1.0.10`. It also omits the upstream GPL-linked `CodableExtension.swift` and substitutes an
independently authored Apache-2.0 compatibility helper for the small Codable/flattening API that
Core calls. `CFSetup.swift`, `CoreConstants.swift`, and `CFActionListener.swift` contain small
wrapper-specific changes so the runtime pause flag safely stops and resumes automatic action
listening. `CFNotificationController.swift` contains the wrapper's notification-authorization and
delegate-forwarding integration. All other included Swift sources and the upstream
`MMKV.xcframework` are unmodified.
The MMKV binary is BSD-3-Clause licensed, and the Core sources include BSD-2-Clause
`Reachability.swift`; their copyright and license terms are retained in
`Runtime/Plugins/iOS/Native~/KenkaiCore/NOTICE.md`.
