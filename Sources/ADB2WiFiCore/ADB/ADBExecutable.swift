import Foundation

/// File-system queries used by ADB discovery. Tests inject in-memory fakes instead of subclassing `FileManager`.
public protocol FileChecking {
    func fileExists(atPath path: String) -> Bool
    func isExecutableFile(atPath path: String) -> Bool
    func isDirectory(atPath path: String) -> Bool
}

extension FileChecking {
    public func isDirectory(atPath path: String) -> Bool { false }
}

extension FileManager: FileChecking {
    public func isDirectory(atPath path: String) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}

public enum ADBExecutable {
    /// Environment escape hatch for power users and CI. Takes priority over the UI setting.
    public static let environmentOverrideKey = "ADB2WIFI_ADB_PATH"

    /// First existing regular executable. An explicit override always wins, then an
    /// `ADB2WIFI_ADB_PATH` environment value, then the common installs, then `PATH`.
    public static func resolve(
        override: URL?,
        fileManager: any FileChecking,
        pathEnv: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL? {
        candidates(
            override: override,
            pathEnv: pathEnv,
            environment: environment,
            homeDirectory: homeDirectory
        )
        .first { isExecutableRegularFile($0, fileManager: fileManager) }
    }

    public static func candidates(
        override: URL?,
        pathEnv: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        var candidates: [URL] = []
        if let override, !override.path.isEmpty {
            candidates.append(override)
        }
        if let envPath = environment[environmentOverrideKey], !envPath.isEmpty {
            candidates.append(URL(fileURLWithPath: envPath))
        }
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/adb"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/adb"))
        candidates.append(URL(fileURLWithPath: "/opt/local/bin/adb"))
        candidates.append(
            homeDirectory
                .appendingPathComponent("Library")
                .appendingPathComponent("Android")
                .appendingPathComponent("sdk")
                .appendingPathComponent("platform-tools")
                .appendingPathComponent("adb")
        )
        for key in ["ANDROID_HOME", "ANDROID_SDK_ROOT"] {
            guard let root = environment[key], !root.isEmpty else { continue }
            candidates.append(
                URL(fileURLWithPath: root)
                    .appendingPathComponent("platform-tools")
                    .appendingPathComponent("adb")
            )
        }
        for directory in pathEnv.split(separator: ":", omittingEmptySubsequences: true) {
            candidates.append(URL(fileURLWithPath: String(directory)).appendingPathComponent("adb"))
        }
        return candidates
    }

    private static func isExecutableRegularFile(_ url: URL, fileManager: any FileChecking) -> Bool {
        let path = url.path
        guard fileManager.fileExists(atPath: path), !fileManager.isDirectory(atPath: path) else {
            return false
        }
        return fileManager.isExecutableFile(atPath: path)
    }
}
