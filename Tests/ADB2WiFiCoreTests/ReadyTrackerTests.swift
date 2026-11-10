import Foundation
import Testing
@testable import ADB2WiFiCore

@Test func readyTrackerReportsOnlyNewlyReadyDevices() {
    var tracker = ReadyTracker()
    var device = Device.testUSBAuthorized
    device.operation = .readyToUnplug

    #expect(tracker.newlyReady(in: [device]).count == 1)
    #expect(tracker.newlyReady(in: [device]).isEmpty)

    device.operation = .idle
    _ = tracker.newlyReady(in: [device])
    device.operation = .readyToUnplug
    #expect(tracker.newlyReady(in: [device]).count == 1)
}

@Test func readyTrackerIgnoresConnectingAndIdleDevices() {
    var tracker = ReadyTracker()
    var device = Device.testUSBAuthorized
    device.operation = .connecting(.verifying)

    #expect(tracker.newlyReady(in: [device]).isEmpty)
    device.operation = .idle
    #expect(tracker.newlyReady(in: [device]).isEmpty)
}

@Test func readyTrackerHandlesMultipleDevicesIndependently() {
    var tracker = ReadyTracker()
    var first = Device.testUSBAuthorized
    first.operation = .readyToUnplug
    var second = Device(
        identity: DeviceIdentity(serialNo: "TEST00000002"),
        model: "Pixel 8 Pro",
        usb: Transport(serial: "TEST00000002", state: .device)
    )
    second.operation = .readyToUnplug

    #expect(Set(tracker.newlyReady(in: [first, second]).map(\.identity.serialNo)) == ["TEST00000001", "TEST00000002"])
    #expect(tracker.newlyReady(in: [first, second]).isEmpty)
    #expect(tracker.newlyReady(in: [second]).isEmpty)
}

@Test func readyTrackerReportsAgainAfterDeviceComesBack() {
    var tracker = ReadyTracker()
    var device = Device.testUSBAuthorized
    device.operation = .readyToUnplug
    _ = tracker.newlyReady(in: [device])

    _ = tracker.newlyReady(in: [])
    #expect(tracker.newlyReady(in: [device]).count == 1)
}
