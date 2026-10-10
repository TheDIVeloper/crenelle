//
//  SoundView.swift
//  Crenelle
//
//  Sound tab. Created 2026-10-10 by Ian L.
//

import CoreAudio
import SwiftUI

struct SoundView: View {
    @ObservedObject private var devices = AudioDeviceManager.shared
    @ObservedObject private var volume = VolumeManager.shared

    @State private var inputVolume: Double = 0
    @State private var inputMuted = false
    @State private var inputSupportsVolume = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                outputSection
                Divider().overlay(.white.opacity(0.1))
                inputSection
                Divider().overlay(.white.opacity(0.1))
                PerAppMixerView()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 380)
        .onAppear { devices.refresh(); loadInput() }
        .onChange(of: devices.defaultInputID) { _, _ in loadInput() }
    }

    // MARK: - Output

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Output", icon: "hifispeaker.fill")

            deviceList(devices.outputDevices, scopeIcon: "hifispeaker") { device in
                devices.setDefaultOutput(device)
            }

            HStack(spacing: 10) {
                Button {
                    volume.toggleMuteAction()
                } label: {
                    Image(systemName: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 13))
                        .frame(width: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(volume.isMuted ? Color.secondary : Color.white)

                Slider(
                    value: Binding(
                        get: { Double(volume.rawVolume) },
                        set: { volume.setAbsolute(Float($0)) }
                    ),
                    in: 0...1
                )

                Text("\(Int((volume.rawVolume * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }
            .padding(.leading, 2)
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Input", icon: "mic.fill")

            deviceList(devices.inputDevices, scopeIcon: "mic") { device in
                devices.setDefaultInput(device)
            }

            if inputSupportsVolume {
                HStack(spacing: 10) {
                    Button {
                        let target = !inputMuted
                        inputMuted = target
                        devices.writeMute(id: devices.defaultInputID, scope: kAudioDevicePropertyScopeInput, muted: target)
                    } label: {
                        Image(systemName: inputMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 13))
                            .frame(width: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(inputMuted ? Color.secondary : Color.white)

                    Slider(
                        value: Binding(
                            get: { inputVolume },
                            set: { newValue in
                                inputVolume = newValue
                                devices.writeVolume(
                                    id: devices.defaultInputID,
                                    scope: kAudioDevicePropertyScopeInput,
                                    value: Float(newValue)
                                )
                            }
                        ),
                        in: 0...1
                    )

                    Text("\(Int((inputVolume * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
                .padding(.leading, 2)
            } else {
                Text("This input device has no software volume control.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)
            }
        }
    }

    // MARK: - Pieces

    private func sectionTitle(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }

    private func deviceList(
        _ devices: [AudioDevice],
        scopeIcon: String,
        select: @escaping (AudioDevice) -> Void
    ) -> some View {
        VStack(spacing: 4) {
            ForEach(devices) { device in
                Button {
                    select(device)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: scopeIcon)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        Text(device.name)
                            .font(.callout)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        if device.isDefault {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        device.isDefault ? Color.white.opacity(0.08) : Color.white.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadInput() {
        let id = devices.defaultInputID
        if let value = devices.readVolume(id: id, scope: kAudioDevicePropertyScopeInput) {
            inputVolume = Double(value)
            inputSupportsVolume = true
        } else {
            inputSupportsVolume = false
        }
        inputMuted = devices.readMute(id: id, scope: kAudioDevicePropertyScopeInput) ?? false
    }
}
