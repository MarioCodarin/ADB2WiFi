public enum TransportMerger {
    public static func merge(
        existing: [Device],
        transports: [ADBTransport],
        identities: [String: DeviceIdentity],
        models: [String: String]
    ) -> [Device] {
        var grouped: [DeviceIdentity: TransportPair] = [:]
        var discoveredOrder: [DeviceIdentity] = []

        for transport in transports where !transport.isEmulator {
            let identity = identities[transport.serial] ?? DeviceIdentity(serialNo: transport.serial)
            if grouped[identity] == nil {
                discoveredOrder.append(identity)
            }
            grouped[identity, default: TransportPair()].assign(transport)
        }

        var result: [Device] = []
        var emitted: Set<DeviceIdentity> = []

        for old in existing {
            if let pair = grouped[old.identity] {
                result.append(assemble(identity: old.identity, pair: pair, existing: old, models: models))
                emitted.insert(old.identity)
            } else if shouldPreserve(old) {
                result.append(Device(
                    identity: old.identity,
                    model: old.model,
                    usb: nil,
                    network: nil,
                    operation: old.operation
                ))
                emitted.insert(old.identity)
            }
        }

        for identity in discoveredOrder where !emitted.contains(identity) {
            result.append(assemble(identity: identity, pair: grouped[identity]!, existing: nil, models: models))
        }

        return result
    }

    private struct TransportPair {
        var usb: ADBTransport?
        var network: ADBTransport?

        mutating func assign(_ transport: ADBTransport) {
            if transport.isNetwork {
                network = transport
            } else {
                usb = transport
            }
        }
    }

    private static func shouldPreserve(_ device: Device) -> Bool {
        switch device.operation {
        case .idle:
            return false
        case .connecting, .awaitingAddress, .readyToUnplug, .failed:
            return true
        }
    }

    private static func assemble(
        identity: DeviceIdentity,
        pair: TransportPair,
        existing: Device?,
        models: [String: String]
    ) -> Device {
        Device(
            identity: identity,
            model: resolveModel(identity: identity, pair: pair, existing: existing, models: models),
            usb: pair.usb.map { makeTransport($0, existing: existing?.usb) },
            network: pair.network.map { makeTransport($0, existing: existing?.network) },
            operation: existing?.operation ?? .idle
        )
    }

    private static func makeTransport(_ transport: ADBTransport, existing: Transport?) -> Transport {
        let verified = existing?.serial == transport.serial && existing?.verified == true
        return Transport(serial: transport.serial, state: transport.state, verified: verified)
    }

    private static func resolveModel(
        identity: DeviceIdentity,
        pair: TransportPair,
        existing: Device?,
        models: [String: String]
    ) -> String {
        if let model = models[identity.serialNo], !model.isEmpty {
            return model
        }
        if let model = pair.usb?.model, !model.isEmpty {
            return model
        }
        if let model = pair.network?.model, !model.isEmpty {
            return model
        }
        if let model = existing?.model, !model.isEmpty {
            return model
        }
        return ""
    }
}
