// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClipartBrowser",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClipartBrowser", targets: ["ClipartBrowser"]),
        .executable(name: "ClipartKeygen", targets: ["ClipartKeygen"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20")
    ],
    targets: [
        .target(
            name: "ClipartBrowserCore",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .executableTarget(
            name: "ClipartBrowser",
            dependencies: ["ClipartBrowserCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "ClipartKeygen"
        ),
        .testTarget(
            name: "ClipartBrowserTests",
            dependencies: [
                "ClipartBrowserCore",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        )
    ]
)
