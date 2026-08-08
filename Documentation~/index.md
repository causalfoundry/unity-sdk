# Kenkai SDK for Unity

The package exposes a platform-neutral C# facade over Causal Foundry's pinned Kenkai Core SDKs for
Android and iOS. Start here when integrating it into a game:

- [Installation](installation.md): Git URL, local package, version pinning, and clean-project checks.
- [Package README](../README.md): configuration and public API examples.
- [Native integration](native-integration.md): native versions, build mutations, lifecycle timing,
  host responsibilities, and known platform differences.
- [iOS integration](iOS.md): generated Xcode project behavior and native bootstrap details.
- [Release process](release.md): maintainer validation, versioning, tags, and distribution.
- [Changelog](../CHANGELOG.md), [license](../LICENSE.md), and
  [third-party notices](../THIRD%20PARTY%20NOTICES.md).

## Supported surface

Version `1.0.7` includes initialization, identify, portable user and other catalog dimensions,
custom Track events, action fetching, in-app messages, notification permission, action-open
callbacks, and runtime pause/resume. It does not yet expose every native Core event family. Editor
and non-mobile player calls are deterministic no-ops so game code can stay platform-neutral.

## Support and security

Use the [repository issue tracker](https://github.com/causalfoundry/unity-sdk/issues) for SDK
integration problems. Do not include production SDK keys, player identifiers, or event payloads in
public reports. Review consent, store disclosures, native privacy manifests, and generated mobile
projects as part of every host application's release process.
