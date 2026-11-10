import ADB2WiFiCore
import AppKit

/// Opens a real Terminal window already attached to the phone.
@MainActor
enum TerminalLauncher {
    static func openShell(adbPath: URL?, endpoint: String) {
        let adb = adbPath?.path ?? "adb"
        let command = "\(shellQuote(adb)) -s \(shellQuote(endpoint)) shell"
        let source = """
        tell application "Terminal"
            activate
            do script "\(appleScriptEscape(command))"
        end tell
        """

        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if result != nil, error == nil {
            Log.app.notice("opened shell in Terminal")
            return
        }

        Log.app.error("terminal launch failed error=\(String(describing: error), privacy: .private)")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t open Terminal"
        alert.informativeText = "The shell command was copied to the clipboard. Paste it into Terminal."
        alert.runModal()
    }

    /// Single-quote for a POSIX shell; handles paths with spaces or quotes.
    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
