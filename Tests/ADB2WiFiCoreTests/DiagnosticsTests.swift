import Foundation
import Testing
@testable import ADB2WiFiCore

private let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)

@Test func diagnosticsRedactHomeDirectory() {
    let summary = Diagnostics.summary(
        appVersion: "0.2.0",
        adbPath: URL(fileURLWithPath: "/Users/mario/Library/Android/sdk/platform-tools/adb"),
        adbVersion: "37.0.1",
        deviceCount: 2,
        connectedCount: 1,
        lastError: nil,
        now: fixedDate,
        operatingSystem: "27.2.0",
        architecture: "arm64",
        homeDirectory: "/Users/mario"
    )

    #expect(summary.contains("ADB2WiFi 0.2.0"))
    #expect(summary.contains("~/Library/Android/sdk/platform-tools/adb (37.0.1)"))
    #expect(summary.contains("Devices: 2 (1 on Wi-Fi)"))
    #expect(summary.contains("Last error: none"))
    #expect(!summary.contains("/Users/mario"))
    #expect(!summary.contains("mario/Library"))
    #expect(!summary.contains("192.0.2."))
    #expect(summary.contains(Log.subsystem))
}

@Test func diagnosticsIncludeLastErrorButNoSerial() {
    let summary = Diagnostics.summary(
        appVersion: "0.2.0",
        adbPath: nil,
        adbVersion: nil,
        deviceCount: 0,
        connectedCount: 0,
        lastError: .timeout,
        now: fixedDate,
        operatingSystem: "27.2.0",
        architecture: "arm64",
        homeDirectory: "/Users/mario"
    )
    #expect(summary.contains("Last error: timeout"))
    #expect(summary.contains("ADB: not found"))
    #expect(!summary.contains("TEST00000001"))
}

@Test func diagnosticsNeverIncludeRawADBOutput() {
    let summary = Diagnostics.summary(
        appVersion: "0.2.0",
        adbPath: nil,
        adbVersion: nil,
        deviceCount: 0,
        connectedCount: 0,
        lastError: .adbOutput("failed to connect to 192.0.2.42:5555 for TEST00000001"),
        now: fixedDate,
        operatingSystem: "27.2.0",
        architecture: "arm64",
        homeDirectory: "/Users/mario"
    )
    #expect(summary.contains("Last error: adbOutput"))
    #expect(!summary.contains("192.0.2.42"))
    #expect(!summary.contains("TEST00000001"))
}

@Test func redactionLeavesOutsidePathsAlone() {
    #expect(Diagnostics.redact("/opt/homebrew/bin/adb", homeDirectory: "/Users/mario") == "/opt/homebrew/bin/adb")
    #expect(Diagnostics.redact("/Users/mario", homeDirectory: "/Users/mario") == "~")
    #expect(Diagnostics.redact("/Users/mariocodarin/bin/adb", homeDirectory: "/Users/mario") == "/Users/mariocodarin/bin/adb")
}
