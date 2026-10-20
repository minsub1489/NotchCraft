// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchCraft",
    defaultLocalization: "ko",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NotchCraftCore", targets: ["NotchCraftCore"]),
        .executable(name: "NotchCraft", targets: ["NotchCraft"])
    ],
    targets: [
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
        .target(name: "NotchCraftCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "NotchCraft", dependencies: ["NotchCraftCore"], resources: [.process("Resources")]),
        .testTarget(name: "NotchCraftCoreTests", dependencies: ["NotchCraftCore"]),
        .testTarget(name: "NotchCraftAdapterTests", dependencies: ["NotchCraft"], resources: [.copy("Fixtures")])
    ]
)
