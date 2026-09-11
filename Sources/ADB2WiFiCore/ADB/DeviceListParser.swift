public enum DeviceListParser {
    public static func parse(_ stdout: String) -> [ADBTransport] {
        stdout.split(whereSeparator: \.isNewline).compactMap { parseLine($0) }
    }

    private static func parseLine(_ line: Substring) -> ADBTransport? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed == "List of devices attached" { return nil }
        if trimmed.contains("* daemon") { return nil }

        let tokens = trimmed.split(whereSeparator: \.isWhitespace)
        guard tokens.count >= 2 else { return nil }

        let serial = String(tokens[0])
        let state = Availability(adbState: String(tokens[1]))
        var product: String?
        var model: String?
        var usb: String?
        var transportID: String?

        for token in tokens.dropFirst(2) {
            guard let colon = token.firstIndex(of: ":") else { continue }
            let key = token[..<colon]
            let value = String(token[token.index(after: colon)...])
            switch key {
            case "product": product = value
            case "model": model = value.replacingOccurrences(of: "_", with: " ")
            case "usb": usb = value
            case "transport_id": transportID = value
            default: break
            }
        }

        return ADBTransport(
            serial: serial,
            state: state,
            product: product,
            model: model,
            usb: usb,
            transportID: transportID
        )
    }
}

private extension Availability {
    init(adbState: String) {
        switch adbState {
        case "device": self = .device
        case "unauthorized": self = .unauthorized
        case "offline": self = .offline
        default: self = .unknown
        }
    }
}
