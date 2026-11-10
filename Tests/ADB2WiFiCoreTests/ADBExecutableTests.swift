import Foundation
import Testing
@testable import ADB2WiFiCore

private struct ExistsAll: FileChecking {
    func fileExists(atPath path: String) -> Bool { true }
    func isExecutableFile(atPath path: String) -> Bool { true }
}

private struct ExistsSet: FileChecking {
    private let paths: Set<String>
    init(_ paths: [String]) { self.paths = Set(paths) }
    func fileExists(atPath path: String) -> Bool { paths.contains(path) }
    func isExecutableFile(atPath path: String) -> Bool { paths.contains(path) }
}

@Test func prefersOverrideWhenItExists() throws {
    let override = URL(fileURLWithPath: "/tmp/adb2wifi-fake-adb")
    #expect(ADBExecutable.resolve(override: override, fileManager: ExistsAll(), pathEnv: "") == override)
}

@Test func searchesHomebrewThenSDKThenPATH() {
    let fm = ExistsSet(["/opt/homebrew/bin/adb", "/Users/me/Library/Android/sdk/platform-tools/adb"])
    let url = ADBExecutable.resolve(override: nil, fileManager: fm,
                                    pathEnv: "/usr/bin:/opt/homebrew/bin")
    #expect(url?.path == "/opt/homebrew/bin/adb")
}

@Test func returnsNilWhenNothingExists() {
    #expect(ADBExecutable.resolve(override: nil, fileManager: ExistsSet([]), pathEnv: "") == nil)
}

@Test func skipsMissingOverrideAndUsesHomebrew() {
    let fm = ExistsSet(["/opt/homebrew/bin/adb"])
    let url = ADBExecutable.resolve(
        override: URL(fileURLWithPath: "/tmp/missing-adb"),
        fileManager: fm,
        pathEnv: ""
    )
    #expect(url?.path == "/opt/homebrew/bin/adb")
}

@Test func usesUsrLocalWhenHomebrewMissing() {
    let fm = ExistsSet(["/usr/local/bin/adb"])
    let url = ADBExecutable.resolve(override: nil, fileManager: fm, pathEnv: "")
    #expect(url?.path == "/usr/local/bin/adb")
}

@Test func usesHomeSDKWhenPrefixPathsMissing() {
    let fm = ExistsSet(["/Users/me/Library/Android/sdk/platform-tools/adb"])
    let url = ADBExecutable.resolve(
        override: nil,
        fileManager: fm,
        pathEnv: "",
        environment: [:],
        homeDirectory: URL(fileURLWithPath: "/Users/me")
    )
    #expect(url?.path == "/Users/me/Library/Android/sdk/platform-tools/adb")
}

@Test func usesAndroidHomeWhenStandardPathsMissing() {
    let fm = ExistsSet(["/custom/sdk/platform-tools/adb"])
    let url = ADBExecutable.resolve(
        override: nil,
        fileManager: fm,
        pathEnv: "",
        environment: ["ANDROID_HOME": "/custom/sdk"],
        homeDirectory: URL(fileURLWithPath: "/Users/me")
    )
    #expect(url?.path == "/custom/sdk/platform-tools/adb")
}

@Test func usesAndroidSDKRootWhenAndroidHomeMissing() {
    let fm = ExistsSet(["/sdk-root/platform-tools/adb"])
    let url = ADBExecutable.resolve(
        override: nil,
        fileManager: fm,
        pathEnv: "",
        environment: ["ANDROID_SDK_ROOT": "/sdk-root"],
        homeDirectory: URL(fileURLWithPath: "/Users/me")
    )
    #expect(url?.path == "/sdk-root/platform-tools/adb")
}

@Test func searchesPATHLast() {
    let fm = ExistsSet(["/opt/bin/adb", "/usr/bin/adb"])
    let url = ADBExecutable.resolve(
        override: nil,
        fileManager: fm,
        pathEnv: "/usr/bin:/opt/bin",
        environment: [:],
        homeDirectory: URL(fileURLWithPath: "/Users/me")
    )
    #expect(url?.path == "/usr/bin/adb")
}

@Test func skipsNonExecutableOverride() {
    struct ExistsButNotExecutable: FileChecking {
        func fileExists(atPath path: String) -> Bool { path == "/tmp/not-exec-adb" }
        func isExecutableFile(atPath path: String) -> Bool { false }
    }
    let url = ADBExecutable.resolve(
        override: URL(fileURLWithPath: "/tmp/not-exec-adb"),
        fileManager: ExistsButNotExecutable(),
        pathEnv: ""
    )
    #expect(url == nil)
}

@Test func environmentPathWinsOverStandardLocations() {
    let fm = ExistsSet(["/opt/homebrew/bin/adb", "/custom/adb"])
    let url = ADBExecutable.resolve(
        override: nil,
        fileManager: fm,
        pathEnv: "",
        environment: [ADBExecutable.environmentOverrideKey: "/custom/adb"],
        homeDirectory: URL(fileURLWithPath: "/Users/me")
    )
    #expect(url?.path == "/custom/adb")
}

@Test func explicitOverrideWinsOverEnvironment() {
    let fm = ExistsSet(["/tmp/chosen-adb", "/custom/adb"])
    let url = ADBExecutable.resolve(
        override: URL(fileURLWithPath: "/tmp/chosen-adb"),
        fileManager: fm,
        pathEnv: "",
        environment: [ADBExecutable.environmentOverrideKey: "/custom/adb"],
        homeDirectory: URL(fileURLWithPath: "/Users/me")
    )
    #expect(url?.path == "/tmp/chosen-adb")
}

@Test func emptyEnvironmentPathIsIgnored() {
    let fm = ExistsSet(["/opt/homebrew/bin/adb"])
    let url = ADBExecutable.resolve(
        override: nil,
        fileManager: fm,
        pathEnv: "",
        environment: [ADBExecutable.environmentOverrideKey: ""],
        homeDirectory: URL(fileURLWithPath: "/Users/me")
    )
    #expect(url?.path == "/opt/homebrew/bin/adb")
}
