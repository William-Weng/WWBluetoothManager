// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WWBluetoothManager",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "WWBluetoothManager", targets: ["WWBluetoothManager"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "WWBluetoothManager", dependencies: []),
        .testTarget(name: "WWBluetoothManagerTests", dependencies: ["WWBluetoothManager"]),
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
