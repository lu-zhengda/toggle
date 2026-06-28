import Foundation
import IOBluetooth

/// Toggle the Bluetooth controller power. macOS has no public CLI/API for this,
/// so we resolve the two private C functions out of IOBluetooth at runtime.
enum BluetoothPower {
    private typealias GetFn = @convention(c) () -> Int32
    private typealias SetFn = @convention(c) (Int32) -> Void

    private static let handle = dlopen(
        "/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth", RTLD_LAZY)

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

    static func isOn() -> Bool { (getFn?() ?? 0) != 0 }

    static func set(_ on: Bool) { setFn?(on ? 1 : 0) }

    private static func connectedDevices() -> [IOBluetoothDevice] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }
        return paired.filter { $0.isConnected() }
    }

    /// Names of everything currently connected (so we can list what will drop).
    static func connectedDeviceNames() -> [String] {
        connectedDevices().compactMap { $0.name }
    }

    /// True if a keyboard / mouse / pointing device is connected — the dangerous
    /// case, since turning Bluetooth off can leave the user with no input.
    static func hasConnectedInputDevice() -> Bool {
        connectedDevices().contains { device in
            // Major device class is bits 8–12 of the class-of-device; 0x05 = Peripheral.
            ((device.classOfDevice >> 8) & 0x1F) == 0x05
        }
    }
}

/// Quick-connect to a paired AirPods (or any device whose name contains "AirPods").
enum AirPods {
    static func device() -> IOBluetoothDevice? {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return nil
        }
        return paired.first { ($0.name ?? "").localizedCaseInsensitiveContains("AirPods") }
    }

    static var isAvailable: Bool { device() != nil }

    static func isConnected() -> Bool { device()?.isConnected() ?? false }

    /// Connect/disconnect. The open/close calls block for a couple seconds, so
    /// callers should invoke this off the main thread.
    static func toggle() {
        guard let device = device() else { return }
        if device.isConnected() {
            device.closeConnection()
        } else {
            device.openConnection()
        }
    }
}
