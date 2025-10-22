// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WWBluetoothManager",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "WWBluetoothManager", targets: ["WWBluetoothManager"]),
    ],
    dependencies: [
        .package(url: "https://github.com/William-Weng/WWOrderedSet", from: "1.0.0")
    ],
    targets: [
        .target(name: "WWBluetoothManager", dependencies: ["WWOrderedSet"], resources: [.copy("Privacy")])
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
