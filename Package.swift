// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "URLImage",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v5)
    ],
    products: [
        .library(name: "URLImage", targets: ["URLImage"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Nuke.git", .branch("master"))
    ],
    targets: [
        .target(name: "URLImage", dependencies: ["Nuke"], path: "Sources")
    ]
)
