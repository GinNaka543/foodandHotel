// swift-tools-version: 6.0
// This is a Skip (https://skip.tools) package.
import PackageDescription

let package = Package(
    name: "happiness-game-skip",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HappinessGameSkip", type: .dynamic, targets: ["HappinessGameSkip"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.6.6"),
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "HappinessGameSkip", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
