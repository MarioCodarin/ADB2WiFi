public struct WiFiAddress: Equatable, Sendable {
    public var interface: String
    public var ipv4: String

    public init(interface: String, ipv4: String) {
        self.interface = interface
        self.ipv4 = ipv4
    }
}

public enum WiFiAddressParser {
    public static func parse(_ stdout: String) -> [WiFiAddress] {
        stdout.split(whereSeparator: \.isNewline).compactMap(parseLine)
    }

    public static func unambiguous(_ addresses: [WiFiAddress]) -> WiFiAddress? {
        let wifiLike = addresses.filter { isWiFiLike($0.interface) }
        guard wifiLike.count == 1 else { return nil }
        return wifiLike[0]
    }

    private static func parseLine(_ line: Substring) -> WiFiAddress? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let match = trimmed.firstMatch(of: /^\d+:\s+(\S+)\s+inet\s+(\d+\.\d+\.\d+\.\d+)/) else {
            return nil
        }
        let interface = String(match.1)
        let ipv4 = String(match.2)
        guard isWiFiLike(interface) else { return nil }
        return WiFiAddress(interface: interface, ipv4: ipv4)
    }

    private static func isWiFiLike(_ name: String) -> Bool {
        if isSkipped(name) { return false }
        if name == "ap0" { return true }
        return name.hasPrefix("wlan")
            || name.hasPrefix("wifi")
            || name.hasPrefix("wl")
            || name.hasPrefix("swlan")
    }

    private static func isSkipped(_ name: String) -> Bool {
        if name == "lo" { return true }
        return name.hasPrefix("dummy")
            || name.hasPrefix("rmnet")
            || name.hasPrefix("ccmni")
            || name.hasPrefix("tun")
            || name.hasPrefix("ppp")
            || name.hasPrefix("sit")
            || name.hasPrefix("ip6tnl")
            || name.hasPrefix("usb")
    }
}
