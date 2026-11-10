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

@Test @MainActor
func autoReconnectDefaultsOnAndPersists() {
    let storage = InMemoryDefaults()
    let settings = AppSettings(storage: storage)
    #expect(settings.autoReconnect)

    settings.autoReconnect = false
    #expect(AppSettings(storage: storage).autoReconnect == false)

    settings.autoReconnect = true
    #expect(AppSettings(storage: storage).autoReconnect)
}

@Test @MainActor
func rememberedConnectionsPersistModelAndForget() {
    let storage = InMemoryDefaults()
    let settings = AppSettings(storage: storage)
    #expect(settings.rememberedConnections.isEmpty)

    settings.remember(endpoint: "192.0.2.42:5555", model: "Pixel 8", for: "TEST00000001")
    settings.remember(endpoint: "192.0.2.43:5555", for: "TEST00000002")
    #expect(settings.rememberedEndpoint(for: "TEST00000001") == "192.0.2.42:5555")
    #expect(settings.rememberedConnection(for: "TEST00000001")?.model == "Pixel 8")

    let restored = AppSettings(storage: storage)
    #expect(restored.rememberedConnections.count == 2)
    #expect(restored.rememberedEndpoint(for: "TEST00000002") == "192.0.2.43:5555")
    #expect(restored.rememberedConnection(for: "TEST00000001")?.model == "Pixel 8")

    restored.forgetEndpoint(for: "TEST00000001")
    #expect(restored.rememberedEndpoint(for: "TEST00000001") == nil)
    #expect(AppSettings(storage: storage).rememberedConnections.count == 1)

    restored.clearRememberedEndpoints()
    #expect(restored.rememberedConnections.isEmpty)
    #expect(AppSettings(storage: storage).rememberedConnections.isEmpty)
}

@Test @MainActor
func rememberedConnectionsAreCapped() {
    let settings = AppSettings(storage: InMemoryDefaults())
    for index in 0..<25 {
        settings.remember(endpoint: "192.0.2.\(index):5555", for: "TEST\(index)")
    }
    #expect(settings.rememberedConnections.count == 20)
}

@Test @MainActor
func emptyRememberedValuesAreIgnored() {
    let settings = AppSettings(storage: InMemoryDefaults())
    settings.remember(endpoint: "", for: "TEST00000001")
    settings.remember(endpoint: "192.0.2.42:5555", for: "")
    #expect(settings.rememberedConnections.isEmpty)
}

@Test @MainActor
func notifyOnReadyDefaultsOffAndPersists() {
    let storage = InMemoryDefaults()
    let settings = AppSettings(storage: storage)
    #expect(settings.notifyOnReady == false)

    settings.notifyOnReady = true
    #expect(AppSettings(storage: storage).notifyOnReady)

    settings.notifyOnReady = false
    #expect(AppSettings(storage: storage).notifyOnReady == false)
}

@Test @MainActor
func rememberingWithoutModelKeepsThePreviousModel() {
    let settings = AppSettings(storage: InMemoryDefaults())
    settings.remember(endpoint: "192.0.2.42:5555", model: "Pixel 8", for: "TEST00000001")
    settings.remember(endpoint: "198.51.100.55:6000", for: "TEST00000001")

    let connection = settings.rememberedConnection(for: "TEST00000001")
    #expect(connection?.endpoint == "198.51.100.55:6000")
    #expect(connection?.model == "Pixel 8")
}

@Test @MainActor
func legacyRememberedEndpointJSONMigrates() {
    let storage = InMemoryDefaults()
    storage.set(#"{"TEST00000001":"192.0.2.42:5555"}"#, forKey: AppSettings.rememberedEndpointsKey)
    let settings = AppSettings(storage: storage)

    #expect(settings.rememberedEndpoint(for: "TEST00000001") == "192.0.2.42:5555")
    #expect(settings.rememberedConnection(for: "TEST00000001")?.model == "")
}
