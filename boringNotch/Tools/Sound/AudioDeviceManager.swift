//
//  AudioDeviceManager.swift
//  Crenelle
//
//  Enumerates audio devices and switches the system defaults. Created 2026-10-10 by Ian L.
//

import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Equatable {
    let id: AudioObjectID
    let name: String
    let uid: String

    var isDefault: Bool = false
}

@MainActor
final class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()

    @Published private(set) var outputDevices: [AudioDevice] = []
    @Published private(set) var inputDevices: [AudioDevice] = []
    @Published private(set) var defaultOutputID: AudioObjectID = kAudioObjectUnknown
    @Published private(set) var defaultInputID: AudioObjectID = kAudioObjectUnknown

    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private let queue = DispatchQueue(label: "io.crenelle.sound.devices")

    private init() {
        installListeners()
        refresh()
    }

    // MARK: - Enumeration

    func refresh() {
        let outputDefault = defaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
        let inputDefault = defaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
        defaultOutputID = outputDefault
        defaultInputID = inputDefault

        var outputs: [AudioDevice] = []
        var inputs: [AudioDevice] = []

        for id in allDeviceIDs() {
            guard let name = deviceName(id) else { continue }
            let uid = deviceUID(id) ?? "\(id)"
            if streamCount(id: id, scope: kAudioDevicePropertyScopeOutput) > 0 {
                outputs.append(AudioDevice(id: id, name: name, uid: uid, isDefault: id == outputDefault))
            }
            if streamCount(id: id, scope: kAudioDevicePropertyScopeInput) > 0 {
                inputs.append(AudioDevice(id: id, name: name, uid: uid, isDefault: id == inputDefault))
            }
        }

        outputDevices = outputs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        inputDevices = inputs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func setDefaultOutput(_ device: AudioDevice) {
        setDefault(selector: kAudioHardwarePropertyDefaultOutputDevice, device: device.id)
        refresh()
    }

    func setDefaultInput(_ device: AudioDevice) {
        setDefault(selector: kAudioHardwarePropertyDefaultInputDevice, device: device.id)
        refresh()
    }

    // MARK: - Volume for an arbitrary device and scope

    func readVolume(id: AudioObjectID, scope: AudioObjectPropertyScope) -> Float? {
        let elements = volumeElements(id: id, scope: scope)
        guard !elements.isEmpty else { return nil }
        var values: [Float32] = []
        for element in elements {
            var address = volumeAddress(scope: scope, element: element)
            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr {
                values.append(value)
            }
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float32(values.count)
    }

    func writeVolume(id: AudioObjectID, scope: AudioObjectPropertyScope, value: Float) {
        let clamped = max(0, min(1, value))
        for element in volumeElements(id: id, scope: scope) {
            var address = volumeAddress(scope: scope, element: element)
            var target = clamped
            AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &target)
        }
    }

    func readMute(id: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool? {
        var address = muteAddress(scope: scope)
        guard AudioObjectHasProperty(id, &address) else { return nil }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &muted) == noErr else { return nil }
        return muted != 0
    }

    func writeMute(id: AudioObjectID, scope: AudioObjectPropertyScope, muted: Bool) {
        var address = muteAddress(scope: scope)
        guard AudioObjectHasProperty(id, &address) else { return }
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    func supportsVolume(id: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        !volumeElements(id: id, scope: scope).isEmpty
    }

    // MARK: - Helpers

    private func volumeElements(id: AudioObjectID, scope: AudioObjectPropertyScope) -> [UInt32] {
        [kAudioObjectPropertyElementMain, 1, 2].filter { probeScalar(id: id, scope: scope, element: $0) }
    }

    private func volumeAddress(scope: AudioObjectPropertyScope, element: UInt32) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: scope,
            mElement: element
        )
    }

    private func muteAddress(scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func probeScalar(id: AudioObjectID, scope: AudioObjectPropertyScope, element: UInt32) -> Bool {
        var address = volumeAddress(scope: scope, element: element)
        guard AudioObjectHasProperty(id, &address) else { return false }
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr
            && size == UInt32(MemoryLayout<Float32>.size)
    }

    private func allDeviceIDs() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        ) == noErr else { return [] }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids
        ) == noErr else { return [] }
        return ids
    }

    private func deviceName(_ id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr,
              let value = name?.takeRetainedValue() else { return nil }
        return value as String
    }

    private func deviceUID(_ id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var unmanaged: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &unmanaged) == noErr,
              let value = unmanaged?.takeRetainedValue() else { return nil }
        return value as String
    }

    private func streamCount(id: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr else { return 0 }
        return Int(size) / MemoryLayout<AudioStreamID>.size
    }

    private func defaultDevice(selector: AudioObjectPropertySelector) -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return device
    }

    private func setDefault(selector: AudioObjectPropertySelector, device: AudioObjectID) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = device
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
            UInt32(MemoryLayout<AudioObjectID>.size), &id
        )
    }

    // MARK: - Listeners

    private func installListeners() {
        let selectors: [AudioObjectPropertySelector] = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultInputDevice,
        ]
        for selector in selectors {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in self?.refresh() }
            }
            let status = AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, queue, block
            )
            if status == noErr {
                listeners.append((AudioObjectID(kAudioObjectSystemObject), address, block))
            }
        }
    }
}
