// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ManotApp",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/smittytone/HighlighterSwift.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ManotApp",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Highlighter", package: "HighlighterSwift")
            ],
            path: "Sources/ManotApp",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
