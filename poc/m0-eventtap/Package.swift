// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "m0-eventtap",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "m0-eventtap")
    ],
    swiftLanguageModes: [.v5]
)
