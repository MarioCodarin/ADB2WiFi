import os

/// Central logging. Everything goes to the unified log under one subsystem so users and
/// maintainers can inspect behaviour without a debugger:
///
///     log stream --predicate 'subsystem == "io.github.mariocodarin.ADB2WiFi"' --level debug
///
/// Serial numbers, IP endpoints and error payloads are always interpolated as `.private`.
public enum Log {
    public static let subsystem = "io.github.mariocodarin.ADB2WiFi"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let adb = Logger(subsystem: subsystem, category: "adb")
    public static let devices = Logger(subsystem: subsystem, category: "devices")
    public static let connection = Logger(subsystem: subsystem, category: "connection")
    public static let settings = Logger(subsystem: subsystem, category: "settings")
}

extension Duration {
    /// Whole milliseconds, for compact log lines.
    public var inMilliseconds: Int {
        let components = self.components
        let seconds = components.seconds * 1_000
        let attos = components.attoseconds / 1_000_000_000_000_000
        return Int(clamping: seconds + attos)
    }
}
