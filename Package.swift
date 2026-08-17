// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PaperMon",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "PaperMon", targets: ["PaperMon"]),
    ],
    targets: [
        .executableTarget(
            name: "PaperMon",
            path: "PaperMon",
            exclude: ["PaperMon.entitlements"]
        ),
        .testTarget(
            name: "PaperMonTests",
            dependencies: ["PaperMon"],
            path: "PaperMonTests"
        ),
    ]
)

