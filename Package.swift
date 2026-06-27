// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SovereignBoard2",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SovereignBoard2", targets: ["SovereignBoard2App"])
    ],
    targets: [
        .executableTarget(name: "SovereignBoard2App"),
        .testTarget(name: "SovereignBoard2Tests", dependencies: ["SovereignBoard2App"])
    ]
)
