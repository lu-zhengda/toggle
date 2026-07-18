import Foundation
import CoreAudio

struct AudioDevice: Identifiable, Equatable, Sendable {
    let id: AudioDeviceID
    let name: String
}

/// Reads and switches the system default audio output device via CoreAudio.
enum AudioOutput {
    private static func address(_ selector: AudioObjectPropertySelector,
                                _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal)
        -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var addr = address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr && size > 0
    }

    private static func name(_ id: AudioDeviceID) -> String {
        var addr = address(kAudioObjectPropertyName)
        var cfName: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &cfName) {
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
        }
        return status == noErr ? (cfName as String) : "Unknown"
    }

    static func outputDevices() -> [AudioDevice] {
        allDeviceIDs()
            .filter(hasOutput)
            .map { AudioDevice(id: $0, name: name($0)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func currentDeviceID() -> AudioDeviceID {
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &device)
        return status == noErr ? device : 0
    }

    @discardableResult
    static func setDevice(_ id: AudioDeviceID) -> Bool {
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        var device = id
        let outputStatus = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &device)

        // Keep alert/system sounds on the same route when the device supports it.
        var systemAddr = address(kAudioHardwarePropertyDefaultSystemOutputDevice)
        _ = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &systemAddr, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &device)
        return outputStatus == noErr
    }

    /// Switch to the next output device in the list (wraps around).
    @discardableResult
    static func cycle() -> Bool {
        let devices = outputDevices()
        guard devices.count > 1 else { return false }
        let current = currentDeviceID()
        let idx = devices.firstIndex { $0.id == current } ?? -1
        return setDevice(devices[(idx + 1) % devices.count].id)
    }
}
