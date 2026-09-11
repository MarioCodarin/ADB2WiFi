import Testing
@testable import ADB2WiFiCore

private let wlan0Only = """
1: lo    inet 127.0.0.1/8 ...
12: wlan0    inet 192.0.2.42/24 ...
14: rmnet_data0 inet 10.132.4.8/30 ...
"""

private let samsungAP = """
12: wlan0 inet 192.0.2.42/24
13: swlan0 inet 198.51.100.43/24
"""

private let wifi0Only = """
8: wifi0 inet 203.0.113.15/24
"""

private let loopbackAndRmnet = """
1: lo    inet 127.0.0.1/8 ...
14: rmnet_data0 inet 10.132.4.8/30 ...
"""

private let skippedInterfaces = """
1: lo inet 127.0.0.1/8
2: dummy0 inet 10.0.0.1/24
3: rmnet_data0 inet 10.132.4.8/30
4: ccmni0 inet 10.1.1.1/32
5: tun0 inet 10.2.2.2/32
6: ppp0 inet 10.3.3.3/32
7: sit0 inet 10.4.4.4/32
8: ip6tnl0 inet 10.5.5.5/32
9: usb0 inet 198.51.100.42/24
10: eth0 inet 198.51.100.5/24
"""

@Test func wlan0AmongLoopbackAndRmnetIsUnambiguous() {
    let addresses = WiFiAddressParser.parse(wlan0Only)
    #expect(addresses == [WiFiAddress(interface: "wlan0", ipv4: "192.0.2.42")])
    #expect(WiFiAddressParser.unambiguous(addresses) == WiFiAddress(interface: "wlan0", ipv4: "192.0.2.42"))
}

@Test func samsungWlanAndSwlanIsAmbiguous() {
    let addresses = WiFiAddressParser.parse(samsungAP)
    #expect(addresses == [
        WiFiAddress(interface: "wlan0", ipv4: "192.0.2.42"),
        WiFiAddress(interface: "swlan0", ipv4: "198.51.100.43"),
    ])
    #expect(WiFiAddressParser.unambiguous(addresses) == nil)

    let suggestion = addresses.first {
        $0.interface.hasPrefix("wlan") || $0.interface.hasPrefix("wifi")
    }
    #expect(suggestion?.ipv4 == "192.0.2.42")
}

@Test func wifi0IsUnambiguous() {
    let addresses = WiFiAddressParser.parse(wifi0Only)
    #expect(addresses == [WiFiAddress(interface: "wifi0", ipv4: "203.0.113.15")])
    #expect(WiFiAddressParser.unambiguous(addresses)?.ipv4 == "203.0.113.15")
}

@Test func onlyLoopbackAndRmnetYieldsNoWiFiAddress() {
    let addresses = WiFiAddressParser.parse(loopbackAndRmnet)
    #expect(addresses.isEmpty)
    #expect(WiFiAddressParser.unambiguous(addresses) == nil)
}

@Test func skipsCellularDummyTunnelAndUsbInterfaces() {
    let addresses = WiFiAddressParser.parse(skippedInterfaces)
    #expect(addresses.isEmpty)
    #expect(WiFiAddressParser.unambiguous(addresses) == nil)
}

@Test func treatsWlAndAp0AsWiFiLike() {
    let wl = WiFiAddressParser.parse("5: wl0 inet 198.51.100.10/24")
    #expect(WiFiAddressParser.unambiguous(wl) == WiFiAddress(interface: "wl0", ipv4: "198.51.100.10"))

    let ap = WiFiAddressParser.parse("6: ap0 inet 198.51.100.43/24")
    #expect(WiFiAddressParser.unambiguous(ap) == WiFiAddress(interface: "ap0", ipv4: "198.51.100.43"))
}

@Test func ignoresIPv6Lines() {
    let stdout = """
    12: wlan0 inet6 fe80::1/64
    12: wlan0 inet 192.0.2.42/24
    """
    let addresses = WiFiAddressParser.parse(stdout)
    #expect(addresses == [WiFiAddress(interface: "wlan0", ipv4: "192.0.2.42")])
}

@Test func unambiguousSkipsNonWiFiLikeWhenOneWiFiRemains() {
    let mixed = [
        WiFiAddress(interface: "lo", ipv4: "127.0.0.1"),
        WiFiAddress(interface: "eth0", ipv4: "198.51.100.5"),
        WiFiAddress(interface: "rmnet_data0", ipv4: "10.132.4.8"),
        WiFiAddress(interface: "wlan0", ipv4: "192.0.2.42"),
    ]
    #expect(WiFiAddressParser.unambiguous(mixed) == WiFiAddress(interface: "wlan0", ipv4: "192.0.2.42"))
}

@Test func unambiguousReturnsNilWhenSeveralWiFiLikeRemain() {
    let mixed = [
        WiFiAddress(interface: "wlan0", ipv4: "192.0.2.42"),
        WiFiAddress(interface: "wifi0", ipv4: "203.0.113.15"),
        WiFiAddress(interface: "ap0", ipv4: "198.51.100.43"),
    ]
    #expect(WiFiAddressParser.unambiguous(mixed) == nil)
}
