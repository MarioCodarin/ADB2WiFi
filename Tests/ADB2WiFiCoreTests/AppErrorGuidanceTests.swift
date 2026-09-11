import Testing
@testable import ADB2WiFiCore

@Test func missingADBGuidanceIsExact() {
    #expect(
        AppError.missingADB.guidance
            == "ADB was not found. Choose the executable in Settings. Homebrew installs it at /opt/homebrew/bin/adb."
    )
}

@Test func authorizationPendingGuidanceIsExact() {
    #expect(
        AppError.authorizationPending.guidance
            == "Authorize USB debugging on the phone, then tap Retry."
    )
}

@Test func deviceOfflineGuidanceIsExact() {
    #expect(
        AppError.deviceOffline.guidance
            == "The device is offline. Replug USB and check USB debugging."
    )
}

@Test func missingWiFiAddressGuidanceIsExact() {
    #expect(
        AppError.missingWiFiAddress.guidance
            == "No Wi-Fi IPv4 address found. Join a network, or enter the address."
    )
}

@Test func unreachableEndpointGuidanceIsExact() {
    #expect(
        AppError.unreachableEndpoint.guidance
            == "Could not reach the phone over Wi-Fi. Same network? Then Retry."
    )
}

@Test func usbRemovedGuidanceIsExact() {
    #expect(
        AppError.usbRemoved.guidance
            == "USB was unplugged before Wi-Fi ADB was enabled. Replug and Retry."
    )
}

@Test func timeoutGuidanceIsExact() {
    #expect(
        AppError.timeout.guidance
            == "Timed out waiting for Wi-Fi ADB. Retry while USB is still connected."
    )
}

@Test func identityMismatchGuidanceIsExact() {
    #expect(
        AppError.identityMismatch.guidance
            == "Connected endpoint is a different device. Disconnect it and Retry."
    )
}
