// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "NukeUI",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v5)
    ],
    products: [
        .library(name: "NukeUI", targets: ["NukeUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Nuke.git", from: "10.3.0"),
        .package(url: "https://github.com/kaishin/Gifu", from: "3.0.0")
    ],
    targets: [
        .target(name: "NukeUI", dependencies: [
            .product(name: "Nuke", package: "Nuke"),
            .product(name: "Gifu", package: "Gifu", condition: .when(platforms: [.iOS, .tvOS]))
        ], path: "Sources")
    ]
)
