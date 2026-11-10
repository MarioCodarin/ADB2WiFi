import Foundation

/// A short, paste-able support report. It deliberately contains no serial numbers,
/// IP endpoints, device names, or usernames.
public enum Diagnostics {
    public static func summary(
        appVersion: String,
        adbPath: URL?,
        adbVersion: String?,
        deviceCount: Int,
        connectedCount: Int,
        lastError: AppError?,
        now: Date = Date(),
        operatingSystem: String = ProcessInfo.processInfo.operatingSystemVersionString,
        architecture: String = currentArchitecture,
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let adb: String
        if let adbPath {
            let path = redact(adbPath.path, homeDirectory: homeDirectory)
            adb = adbVersion.map { "\(path) (\($0))" } ?? path
        } else {
            adb = "not found"
        }

        return """
        ADB2WiFi \(appVersion)
        macOS \(operatingSystem) · \(architecture)
        Time: \(formatter.string(from: now))
        ADB: \(adb)
        Devices: \(deviceCount) (\(connectedCount) on Wi-Fi)
        Last error: \(lastError.map { String(describing: $0) } ?? "none")
        Logs: log show --predicate 'subsystem == "\(Log.subsystem)"' --last 15m --info --debug
        """
    }

    public static var currentArchitecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }

    /// Keeps the report anonymous when the user installed ADB inside their home folder.
    static func redact(_ path: String, homeDirectory: String) -> String {
        guard !homeDirectory.isEmpty else { return path }
        if path == homeDirectory { return "~" }
        if path.hasPrefix(homeDirectory + "/") {
            return "~" + path.dropFirst(homeDirectory.count)
        }
        return path
    }
}
