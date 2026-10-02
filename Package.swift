// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HAPPY",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "HAPPY",
            targets: ["HAPPY"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "HAPPY",
            dependencies: [],
            path: "Sources/HAPPY",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "HAPPYTests",
            dependencies: ["HAPPY"],
            path: "Tests/HAPPYTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
