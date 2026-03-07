// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClearNote",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClearNote",
            path: "Sources/ClearNote",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
