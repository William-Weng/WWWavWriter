// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WWWavWriter",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "WWWavWriter", targets: ["WWWavWriter"]),
    ],
    targets: [
        .target(name: "WWWavWriter"),
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
