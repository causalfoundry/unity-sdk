# Release process

The SDK is distributed as a Git-based UPM package from the root of the standalone
`causalfoundry/unity-sdk` repository. Release tags therefore resolve directly through a URL such as
`https://github.com/causalfoundry/unity-sdk.git#v1.0.10`; do not add a `?path=` query.

## Preflight

1. Choose a SemVer version and update `package.json`, `CFSDK.PackageVersion`, and
   `CHANGELOG.md` in the same commit.
2. Run `python3 Tools~/validate_package.py` from the repository root.
3. Run all EditMode tests in Unity 2021.3 LTS and the current Unity 6 version.
4. Build the Android facade AAR with JDK 17. The native build script intentionally rejects other
   Java versions because newer compilers produce metadata that crashes Unity 2021.3's D8.
5. Run `Runtime/Plugins/Android/Native~/verify.sh`, make an Android development build, and verify on
   a fresh install that Core `1.0.10` reports app notification permission correctly when a host-owned
   channel exists but `CF_NOTIFICATION_CHANNEL` does not, then lazily creates its channel when
   delivering a notification action.
6. Run `swift package dump-package` in `Runtime/Plugins/iOS/Native~/KenkaiCore`, export Xcode, and
   build for an iOS device plus simulator.
7. Install the exact committed package into a blank consumer project and import its sample.
8. Run `npm pack --dry-run` from the repository root and inspect the complete archive file list.
9. Review third-party notices, data collection, consent behavior, and Apple/Google privacy metadata.

## Publish

1. Merge the reviewed release commit.
2. Create an immutable annotated tag matching the manifest version, for example `v1.0.10`.
3. Push the commit and tag, then create release notes from `CHANGELOG.md`.
4. Verify a blank Unity project can install
   `https://github.com/causalfoundry/unity-sdk.git#v1.0.10` (updated for the release version) and that
   Package Manager reports the expected package version.
5. Optionally generate a registry-format `.tgz` from the repository-root package, attach its SHA-256
   checksum, and test that exact artifact in a clean project.

Never move a published tag. Starting with `1.0.0`, treat public API/assembly removal, package or
assembly identity changes, serialized GUID changes, and platform-support removal as breaking
changes.
