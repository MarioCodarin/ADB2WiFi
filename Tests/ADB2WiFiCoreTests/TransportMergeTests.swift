import Testing
@testable import ADB2WiFiCore

@Test func mergesUSBAndNetworkByRoSerialNotModel() {
    let usb = ADBTransport(serial: "TEST00000001", state: .device, model: "Pixel_8")
    let net = ADBTransport(serial: "192.0.2.42:5555", state: .device, model: "Pixel_8")
    let otherUSB = ADBTransport(serial: "TEST00000002", state: .device, model: "Pixel_8")
    let identities = [
        "TEST00000001": DeviceIdentity(serialNo: "TEST00000001"),
        "192.0.2.42:5555": DeviceIdentity(serialNo: "TEST00000001"),
        "TEST00000002": DeviceIdentity(serialNo: "TEST00000002"),
    ]
    let merged = TransportMerger.merge(existing: [], transports: [usb, net, otherUSB],
                                       identities: identities, models: [:])
    #expect(merged.count == 2)
    let pixel = merged.first { $0.identity.serialNo == "TEST00000001" }!
    #expect(pixel.usb?.serial == "TEST00000001")
    #expect(pixel.network?.serial == "192.0.2.42:5555")
}

@Test func hidesEmulators() {
    let emu = ADBTransport(serial: "emulator-5554", state: .device, model: "sdk")
    let phone = ADBTransport(serial: "ABC", state: .device, model: "Pixel")
    let merged = TransportMerger.merge(existing: [], transports: [emu, phone],
                                       identities: ["ABC": .init(serialNo: "ABC")], models: [:])
    #expect(merged.map(\.identity.serialNo) == ["ABC"])
}

@Test func keepsConnectingCardWhenUSBDropsDuringRestart() {
    var existing = Device.fixtureUSBAuthorized
    existing.operation = .connecting(.enablingWifi)
    let merged = TransportMerger.merge(existing: [existing], transports: [],
                                       identities: [:], models: [:])
    #expect(merged.count == 1)
    #expect(merged[0].operation == .connecting(.enablingWifi))
}

@Test func keepsVerifiedWifiCardAfterUSBUnplug() {
    var existing = Device.fixtureUSBAuthorized
    existing.network = .init(serial: "192.0.2.42:5555", state: .device, verified: true)
    existing.operation = .readyToUnplug
    let net = ADBTransport(serial: "192.0.2.42:5555", state: .device, model: "Pixel_8")
    let merged = TransportMerger.merge(
        existing: [existing], transports: [net],
        identities: ["192.0.2.42:5555": existing.identity], models: [:]
    )
    #expect(merged.count == 1)
    #expect(merged[0].usb == nil)
    #expect(merged[0].isWiFiConnected)
    #expect(merged[0].operation == .readyToUnplug)
}

@Test func showsUnauthorizedUSB() {
    let usb = ADBTransport(serial: "ABCDEF12", state: .unauthorized)
    let merged = TransportMerger.merge(
        existing: [], transports: [usb], identities: [:], models: [:]
    )
    #expect(merged.count == 1)
    #expect(merged[0].identity.serialNo == "ABCDEF12")
    #expect(merged[0].usb?.serial == "ABCDEF12")
    #expect(merged[0].usb?.state == .unauthorized)
}

@Test func twoPhonesWithSameModelStayTwoRows() {
    let first = ADBTransport(serial: "SERIALA", state: .device, model: "Pixel 8")
    let second = ADBTransport(serial: "SERIALB", state: .device, model: "Pixel 8")
    let merged = TransportMerger.merge(
        existing: [],
        transports: [first, second],
        identities: [
            "SERIALA": DeviceIdentity(serialNo: "SERIALA"),
            "SERIALB": DeviceIdentity(serialNo: "SERIALB"),
        ],
        models: [:]
    )
    #expect(merged.count == 2)
    #expect(Set(merged.map(\.identity.serialNo)) == ["SERIALA", "SERIALB"])
}

@Test func modelCacheSurvivesPollThatOmitsModel() {
    let withModel = ADBTransport(serial: "ABC", state: .device, model: "Pixel 8")
    let first = TransportMerger.merge(
        existing: [],
        transports: [withModel],
        identities: ["ABC": DeviceIdentity(serialNo: "ABC")],
        models: [:]
    )
    #expect(first.map(\.model) == ["Pixel 8"])

    let withoutModel = ADBTransport(serial: "ABC", state: .device)
    let second = TransportMerger.merge(
        existing: first,
        transports: [withoutModel],
        identities: ["ABC": DeviceIdentity(serialNo: "ABC")],
        models: [:]
    )
    #expect(second.count == 1)
    #expect(second[0].model == "Pixel 8")
}

@Test func prefersGetpropModelOverTransportThenExisting() {
    var existing = Device(
        identity: DeviceIdentity(serialNo: "ABC"),
        model: "Cached Name"
    )
    existing.usb = Transport(serial: "ABC", state: .device)
    let transport = ADBTransport(serial: "ABC", state: .device, model: "Pixel 8")
    let merged = TransportMerger.merge(
        existing: [existing],
        transports: [transport],
        identities: ["ABC": DeviceIdentity(serialNo: "ABC")],
        models: ["ABC": "Pixel 8 Pro"]
    )
    #expect(merged.map(\.model) == ["Pixel 8 Pro"])
}

@Test func dropsIdleDeviceWhenTransportsDisappear() {
    let existing = Device.fixtureUSBAuthorized
    let merged = TransportMerger.merge(
        existing: [existing], transports: [], identities: [:], models: [:]
    )
    #expect(merged.isEmpty)
}

@Test func preservesFailedAndAwaitingAddressWhenUSBDrops() {
    var awaiting = Device.fixtureUSBAuthorized
    awaiting.operation = .awaitingAddress(suggested: "192.0.2.42")
    let failed = Device(
        identity: DeviceIdentity(serialNo: "OTHER"),
        model: "Pixel 8",
        usb: Transport(serial: "OTHER", state: .device),
        operation: .failed(.timeout)
    )
    let merged = TransportMerger.merge(
        existing: [awaiting, failed], transports: [], identities: [:], models: [:]
    )
    #expect(merged.count == 2)
    #expect(merged[0].operation == .awaitingAddress(suggested: "192.0.2.42"))
    #expect(merged[1].operation == .failed(.timeout))
}
