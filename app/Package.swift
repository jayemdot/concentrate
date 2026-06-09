// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Concentrate",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Concentrate")
    ],
    swiftLanguageModes: [.v5]
)
