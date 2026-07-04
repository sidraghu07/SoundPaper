// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudioReactiveWallpaper",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AudioReactiveWallpaper",
            resources: [.process("Shaders.metal"), .copy("app.jpg")]),
    ]
)
