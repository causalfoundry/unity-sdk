// swift-tools-version: 5.4
import PackageDescription

// Modified from Causal Foundry iOS SDK 1.0.10: this wrapper exposes only Core and MMKV, raises the
// declared minimum to iOS 13, and replaces one incompatible Codable helper. See NOTICE.md.
let package = Package(
    name: "KenkaiSDKCorePackage",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "KenkaiSDKCore", targets: ["KenkaiSDKCore"])
    ],
    targets: [
        .target(
            name: "KenkaiSDKCore",
            dependencies: ["MMKV"],
            path: "KenkaiSDKCore/Sources"
        ),
        .binaryTarget(
            name: "MMKV",
            path: "Frameworks/MMKV.xcframework"
        )
    ]
)
