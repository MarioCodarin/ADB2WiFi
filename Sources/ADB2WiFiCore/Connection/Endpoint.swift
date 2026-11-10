public enum Endpoint {
    public static let defaultPort = 5555

    /// `#.#.#.#` (octets 0-255) with an optional `:port` (1-65535).
    /// A missing port is filled with `defaultPort`.
    public static func normalize(_ raw: String, defaultPort: Int = defaultPort) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = trimmed.wholeMatch(of: /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?::(\d{1,5}))?$/) else {
            return nil
        }
        let octets = [match.1, match.2, match.3, match.4].compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ $0 <= 255 }) else { return nil }

        var port = defaultPort
        if let rawPort = match.5 {
            guard let parsed = Int(rawPort), isValidPort(parsed) else { return nil }
            port = parsed
        }
        guard isValidPort(port) else { return nil }
        return "\(octets.map(String.init).joined(separator: ".")):\(port)"
    }

    public static func isValidPort(_ port: Int) -> Bool {
        (1...65535).contains(port)
    }

    /// Prefer the first `wlan*` / `wifi*` (but not `swlan*`); otherwise the first Wi-Fi-like address.
    public static func suggestedIPv4(from addresses: [WiFiAddress]) -> String? {
        if let preferred = addresses.first(where: {
            $0.interface.hasPrefix("wlan") || $0.interface.hasPrefix("wifi")
        }) {
            return preferred.ipv4
        }
        return addresses.first?.ipv4
    }

    /// The exact command shown in the UI for copying into a terminal.
    public static func connectCommand(_ endpoint: String) -> String {
        "adb connect \(endpoint)"
    }
}
