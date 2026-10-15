// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceSwitch",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "VoiceSwitch", targets: ["VoiceSwitch"])],
    targets: [
        .target(name: "VoiceSwitchCore"),
        .executableTarget(name: "VoiceSwitch", dependencies: ["VoiceSwitchCore"]),
        .testTarget(name: "VoiceSwitchCoreTests", dependencies: ["VoiceSwitchCore"])
    ]
)
