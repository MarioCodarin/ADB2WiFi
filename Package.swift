// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ADB2WiFi",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ADB2WiFi", targets: ["ADB2WiFi"]),
        .library(name: "ADB2WiFiCore", targets: ["ADB2WiFiCore"]),
    ],
    targets: [
        .target(name: "ADB2WiFiCore"),
        .executableTarget(name: "ADB2WiFi", dependencies: ["ADB2WiFiCore"]),
        .testTarget(name: "ADB2WiFiCoreTests", dependencies: ["ADB2WiFiCore"]),
    ],
    swiftLanguageModes: [.v6]
)
