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
    private static let queue = DispatchQueue(label: "com.local.toggle.bluetooth-power")

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

/// Quick-connect to a paired AirPods (or any device whose name contains "AirPods").
enum AirPods {
    private static let queue = DispatchQueue(label: "com.local.toggle.airpods")

    private static func device() -> IOBluetoothDevice? {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return nil
        }
        return paired.first { ($0.name ?? "").localizedCaseInsensitiveContains("AirPods") }
    }

    static var isAvailable: Bool { queue.sync { device() != nil } }

    static func isConnected() -> Bool { queue.sync { device()?.isConnected() ?? false } }

    static func status() -> (available: Bool, isConnected: Bool) {
        queue.sync {
            guard let device = device() else { return (false, false) }
            return (true, device.isConnected())
        }
    }

    /// Set an explicit state so queued UI work cannot accidentally invert twice.
    /// The open/close calls can block, so callers invoke this off the main thread.
    @discardableResult
    static func setConnected(_ connected: Bool) -> Bool {
        queue.sync {
            guard let device = device() else { return false }
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
