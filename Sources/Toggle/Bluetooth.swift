import Foundation
import IOBluetooth

struct BluetoothConnectionSummary: Sendable {
    let names: [String]
    let hasInputDevice: Bool
}

/// Toggle the Bluetooth controller power. macOS has no public CLI/API for this,
/// so we resolve the two private C functions out of IOBluetooth at runtime.
enum BluetoothPower {
    private typealias GetFn = @convention(c) () -> Int32
    private typealias SetFn = @convention(c) (Int32) -> Void

    nonisolated(unsafe) private static let handle = dlopen(
        "/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth", RTLD_LAZY)
    private static let queue = DispatchQueue(label: "com.zhengdalu.toggle.bluetooth-power")

    private static let getFn: GetFn? = {
        guard let handle,
              let sym = dlsym(handle, "IOBluetoothPreferenceGetControllerPowerState")
        else { return nil }
        return unsafeBitCast(sym, to: GetFn.self)
    }()

    private static let setFn: SetFn? = {
        guard let handle,
              let sym = dlsym(handle, "IOBluetoothPreferenceSetControllerPowerState")
        else { return nil }
        return unsafeBitCast(sym, to: SetFn.self)
    }()

    static var isAvailable: Bool { getFn != nil && setFn != nil }

    static func isOn() -> Bool { queue.sync { (getFn?() ?? 0) != 0 } }

    @discardableResult
    static func set(_ on: Bool) -> Bool {
        queue.sync {
            guard let setFn, let getFn else { return false }
            setFn(on ? 1 : 0)
            for _ in 0..<20 {
                if (getFn() != 0) == on { return true }
                Thread.sleep(forTimeInterval: 0.1)
            }
            return (getFn() != 0) == on
        }
    }

    private static func connectedDevices() -> [IOBluetoothDevice] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }
        return paired.filter { $0.isConnected() }
    }

    /// Everything the destructive Bluetooth-off warning needs, captured in one
    /// serialized device enumeration.
    static func connectedDeviceSummary() -> BluetoothConnectionSummary {
        queue.sync {
            let devices = connectedDevices()
            let names = devices.enumerated().map { index, device in
                guard let name = device.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else {
                    return "Unnamed Bluetooth device \(index + 1)"
                }
                return name
            }
            let hasInput = devices.contains { device in
                ((device.classOfDevice >> 8) & 0x1F) == 0x05
            }
            return BluetoothConnectionSummary(names: names, hasInputDevice: hasInput)
        }
    }

}

struct AirPodsDevice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let isConnected: Bool
}

struct AirPodsStatus: Sendable {
    let devices: [AirPodsDevice]
    let selectedID: String?

    var selectedDevice: AirPodsDevice? {
        devices.first { $0.id == selectedID }
    }
}

/// Pure selection rules kept separate from IOBluetooth so ambiguous multi-pair
/// behavior can be tested without connecting or disconnecting real hardware.
enum AirPodsSelectionPolicy {
    static func isEligible(name: String) -> Bool {
        name.localizedCaseInsensitiveContains("AirPods")
            && !name.localizedCaseInsensitiveContains("Find My")
    }

    static func selectedID(
        devices: [AirPodsDevice],
        preferredID: String?
    ) -> String? {
        let connected = devices.filter(\.isConnected)
        if let preferredID,
           connected.contains(where: { $0.id == preferredID }) {
            return preferredID
        }
        if let connectedID = connected.first?.id { return connectedID }
        if let preferredID,
           devices.contains(where: { $0.id == preferredID }) {
            return preferredID
        }
        return devices.count == 1 ? devices[0].id : nil
    }
}

/// Quick-connect to a specific paired AirPods device. Find My companion records
/// are excluded because they are not connectable audio devices.
enum AirPods {
    private static let queue = DispatchQueue(label: "com.zhengdalu.toggle.airpods")

    private struct Candidate {
        let device: IOBluetoothDevice
        let summary: AirPodsDevice
    }

    private static func candidates() -> [Candidate] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }
        return paired.compactMap { device in
            guard let rawName = device.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawName.isEmpty,
                  AirPodsSelectionPolicy.isEligible(name: rawName) else {
                return nil
            }
            let id = (device.addressString ?? rawName).lowercased()
            return Candidate(
                device: device,
                summary: AirPodsDevice(
                    id: id,
                    name: rawName,
                    isConnected: device.isConnected()
                )
            )
        }
        .sorted {
            if $0.summary.isConnected != $1.summary.isConnected {
                return $0.summary.isConnected
            }
            return $0.summary.name.localizedStandardCompare($1.summary.name) == .orderedAscending
        }
    }

    static func status(preferredID: String?) -> AirPodsStatus {
        queue.sync {
            let devices = candidates().map(\.summary)
            return AirPodsStatus(
                devices: devices,
                selectedID: AirPodsSelectionPolicy.selectedID(
                    devices: devices,
                    preferredID: preferredID
                )
            )
        }
    }

    /// Set an explicit state so queued UI work cannot accidentally invert twice.
    /// The open/close calls can block, so callers invoke this off the main thread.
    @discardableResult
    static func setConnected(deviceID: String, connected: Bool) -> Bool {
        queue.sync {
            guard let device = candidates()
                .first(where: { $0.summary.id == deviceID })?
                .device else {
                return false
            }
            if device.isConnected() == connected { return true }
            if connected {
                device.openConnection()
            } else {
                device.closeConnection()
            }
            for _ in 0..<30 {
                if device.isConnected() == connected { return true }
                Thread.sleep(forTimeInterval: 0.1)
            }
            return device.isConnected() == connected
        }
    }
}
