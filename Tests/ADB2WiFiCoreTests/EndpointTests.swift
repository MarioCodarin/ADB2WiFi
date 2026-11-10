import Testing
@testable import ADB2WiFiCore

@Test func normalizeAddsDefaultPort() {
    #expect(Endpoint.normalize("192.0.2.42") == "192.0.2.42:5555")
}

@Test func normalizeKeepsExplicitPort() {
    #expect(Endpoint.normalize("192.0.2.42:5037") == "192.0.2.42:5037")
    #expect(Endpoint.normalize(" 192.0.2.42:1 ") == "192.0.2.42:1")
    #expect(Endpoint.normalize("192.0.2.42:65535") == "192.0.2.42:65535")
}

@Test func normalizeUsesCustomDefaultPort() {
    #expect(Endpoint.normalize("198.51.100.7", defaultPort: 6000) == "198.51.100.7:6000")
}

@Test func normalizeRejectsBadInput() {
    #expect(Endpoint.normalize("") == nil)
    #expect(Endpoint.normalize("phone.local") == nil)
    #expect(Endpoint.normalize("192.0.2.256") == nil)
    #expect(Endpoint.normalize("192.0.2") == nil)
    #expect(Endpoint.normalize("192.0.2.42:0") == nil)
    #expect(Endpoint.normalize("192.0.2.42:65536") == nil)
    #expect(Endpoint.normalize("192.0.2.42:abc") == nil)
    #expect(Endpoint.normalize("192.0.2.42:6000", defaultPort: 0) == "192.0.2.42:6000")
    #expect(Endpoint.normalize("192.0.2.42", defaultPort: 0) == nil)
}

@Test func suggestedAddressPrefersWLAN() {
    let addresses = [
        WiFiAddress(interface: "swlan0", ipv4: "198.51.100.43"),
        WiFiAddress(interface: "wlan0", ipv4: "192.0.2.42"),
        WiFiAddress(interface: "wifi0", ipv4: "192.0.2.10"),
    ]
    #expect(Endpoint.suggestedIPv4(from: addresses) == "192.0.2.42")
    #expect(Endpoint.suggestedIPv4(from: []) == nil)
}

@Test func connectCommandIsCopyReady() {
    #expect(Endpoint.connectCommand("192.0.2.42:5555") == "adb connect 192.0.2.42:5555")
}

@Test func portValidation() {
    #expect(Endpoint.isValidPort(1))
    #expect(Endpoint.isValidPort(65535))
    #expect(!Endpoint.isValidPort(0))
    #expect(!Endpoint.isValidPort(65536))
}
