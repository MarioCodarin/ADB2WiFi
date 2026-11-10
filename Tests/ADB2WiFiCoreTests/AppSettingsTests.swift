import Foundation
import Testing
@testable import ADB2WiFiCore

@Test @MainActor
func portDefaultsTo5555() {
    let settings = AppSettings(storage: InMemoryDefaults())
    #expect(settings.port == 5555)
    #expect(settings.adbPathOverride == nil)
}

@Test @MainActor
func portAndPathPersist() {
    let storage = InMemoryDefaults()
    let settings = AppSettings(storage: storage)
    settings.port = 6000
    settings.adbPathOverride = URL(fileURLWithPath: "/opt/homebrew/bin/adb")

    let restored = AppSettings(storage: storage)
    #expect(restored.port == 6000)
    #expect(restored.adbPathOverride?.path == "/opt/homebrew/bin/adb")

    restored.resetADBPath()
    let cleared = AppSettings(storage: storage)
    #expect(cleared.adbPathOverride == nil)
}

@Test @MainActor
func portIsClampedToValidRange() {
    let settings = AppSettings(storage: InMemoryDefaults())
    settings.port = 0
    #expect(settings.port == 1)
    settings.port = 70_000
    #expect(settings.port == 65535)
}

@Test @MainActor
func storedOutOfRangePortIsClampedOnLoad() {
    let storage = InMemoryDefaults()
    storage.set(99_999, forKey: AppSettings.portKey)
    let settings = AppSettings(storage: storage)
    #expect(settings.port == 65535)
}

@Test @MainActor
func emptyStoredPathIsIgnored() {
    let storage = InMemoryDefaults()
    storage.set("", forKey: AppSettings.adbPathOverrideKey)
    let settings = AppSettings(storage: storage)
    #expect(settings.adbPathOverride == nil)
}
