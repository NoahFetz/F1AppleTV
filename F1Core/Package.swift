// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "F1Core",
    platforms: [.macOS("26.0"), .tvOS("26.0")],
    products: [.library(name: "F1Core", targets: ["F1Core"])],
    targets: [
        .target(name: "F1Core", resources: [.process("Resources")]),
        .testTarget(name: "F1CoreTests", dependencies: ["F1Core"])
    ],
    swiftLanguageVersions: [.v5]
)
