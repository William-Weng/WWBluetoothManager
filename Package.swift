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
    ],
    targets: [
        .target(name: "WWBluetoothManager", resources: [.copy("Privacy")])
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
