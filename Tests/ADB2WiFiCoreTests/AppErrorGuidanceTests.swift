import Testing
@testable import ADB2WiFiCore

@Test func missingADBGuidanceIsActionable() {
    #expect(
        AppError.missingADB.guidance
            == "ADB wasn’t found. Install Android Platform Tools or choose your adb in Settings."
    )
    #expect(AppError.missingADB.needsADBSetup)
}

@Test func authorizationPendingGuidanceIsExact() {
    #expect(
        AppError.authorizationPending.guidance
            == "Allow USB debugging on your phone, then try again."
    )
}

@Test func deviceOfflineGuidanceIsExact() {
    #expect(
        AppError.deviceOffline.guidance
            == "Phone is offline. Reconnect the cable and check USB debugging."
    )
}

@Test func missingWiFiAddressGuidanceIsExact() {
    #expect(
        AppError.missingWiFiAddress.guidance
            == "No Wi-Fi address found. Join a Wi-Fi network, or enter the address."
    )
}

@Test func unreachableEndpointGuidanceIsExact() {
    #expect(
        AppError.unreachableEndpoint.guidance
            == "Couldn’t reach the phone. Put both devices on the same network, then retry."
    )
}

@Test func usbRemovedGuidanceIsExact() {
    #expect(
        AppError.usbRemoved.guidance
            == "USB was unplugged too early. Reconnect the cable and try again."
    )
}

@Test func timeoutGuidanceIsExact() {
    #expect(
        AppError.timeout.guidance
            == "ADB timed out. Keep USB connected and try again."
    )
}

@Test func identityMismatchGuidanceIsExact() {
    #expect(
        AppError.identityMismatch.guidance
            == "That endpoint is a different phone. Disconnect it and try again."
    )
}

@Test func launchFailureSendsUserToSetup() {
    #expect(AppError.adbLaunchFailed("nope").needsADBSetup)
    #expect(AppError.adbLaunchFailed("nope").title == "ADB failed")
}

@Test func adbOutputFallsBackWhenEmpty() {
    #expect(AppError.adbOutput("").displayedGuidance == "ADB returned an unexpected error.")
}

@Test func errorTitlesAreShort() {
    #expect(AppError.authorizationPending.title == "Authorization needed")
    #expect(AppError.unreachableEndpoint.title == "Can’t reach phone")
    #expect(AppError.identityMismatch.title == "Wrong device")
}
