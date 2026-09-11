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
    /// First existing regular executable, in order: override, Homebrew, `/usr/local`, `~/Library/Android/sdk`, `$ANDROID_HOME`, `$ANDROID_SDK_ROOT`, then each `PATH` directory.
    public static func resolve(
        override: URL?,
        fileManager: any FileChecking,
        pathEnv: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL? {
        var candidates: [URL] = []
        if let override {
            candidates.append(override)
        }
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/adb"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/adb"))
        candidates.append(
            homeDirectory
                .appendingPathComponent("Library")
                .appendingPathComponent("Android")
                .appendingPathComponent("sdk")
                .appendingPathComponent("platform-tools")
                .appendingPathComponent("adb")
        )
        if let androidHome = environment["ANDROID_HOME"], !androidHome.isEmpty {
            candidates.append(
                URL(fileURLWithPath: androidHome)
                    .appendingPathComponent("platform-tools")
                    .appendingPathComponent("adb")
            )
        }
        if let sdkRoot = environment["ANDROID_SDK_ROOT"], !sdkRoot.isEmpty {
            candidates.append(
                URL(fileURLWithPath: sdkRoot)
                    .appendingPathComponent("platform-tools")
                    .appendingPathComponent("adb")
            )
        }
        for directory in pathEnv.split(separator: ":", omittingEmptySubsequences: true) {
            candidates.append(URL(fileURLWithPath: String(directory)).appendingPathComponent("adb"))
        }
        return candidates.first { isExecutableRegularFile($0, fileManager: fileManager) }
    }

    private static func isExecutableRegularFile(_ url: URL, fileManager: any FileChecking) -> Bool {
        let path = url.path
        guard fileManager.fileExists(atPath: path), !fileManager.isDirectory(atPath: path) else {
            return false
        }
        return fileManager.isExecutableFile(atPath: path)
    }
}
