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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.4"),
    ],
    targets: [
        .executableTarget(
            name: "PaperMon",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "PaperMon",
            exclude: ["PaperMon.entitlements"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .testTarget(
            name: "PaperMonTests",
            dependencies: ["PaperMon"],
            path: "PaperMonTests",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../.."]),
            ]
        ),
    ]
)
