//
//  BoringHeader.swift
//  boringNotch
//
//  Created by Harsh Vardhan Goswami on 04/08/24.
//

import Defaults
import SwiftUI

private struct HeaderWeatherView: View {
    @ObservedObject private var manager = WeatherManager.shared
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @AppStorage("weatherUnit") private var unitRaw: String = TemperatureUnit.celsius.rawValue
    @State private var isHovering: Bool = false

    private var unit: TemperatureUnit {
        TemperatureUnit(rawValue: unitRaw) ?? .celsius
    }

    var body: some View {
        Button {
            withAnimation(.smooth) {
                if coordinator.currentView == .weather {
                    coordinator.currentView = .home
                } else {
                    coordinator.currentView = .weather
                }
            }
        } label: {
            HStack(spacing: 5) {
                if let snapshot = manager.snapshot {
                    Image(systemName: WeatherCode.symbol(for: snapshot.weatherCode, isDay: snapshot.isDay))
                        .font(.system(size: 13, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                    Text(unit.format(snapshot.temperature))
                        .font(.system(size: 12, weight: .medium))
                } else {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 13, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                    Text("--°")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundStyle(coordinator.currentView == .weather ? .white : (isHovering ? .white : .white.opacity(0.85)))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(coordinator.currentView == .weather ? Color.white.opacity(0.2) : (isHovering ? Color.white.opacity(0.12) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(coordinator.currentView == .weather ? "Return to Home" : "Open Weather Forecast")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .task {
            manager.refresh()
        }
    }
}

private struct HeaderIconButton: View {
    let icon: String
    let tooltip: String
    var isActive: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? .white : (isHovering ? .white : .white.opacity(0.8)))
                .frame(width: 24, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isActive ? Color.white.opacity(0.25) : (isHovering ? Color.white.opacity(0.12) : Color.clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

struct BoringHeader: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared

    var body: some View {
        HStack(spacing: 0) {
            // Weather information placed at the top left of the header
            HeaderWeatherView()
                .frame(maxWidth: .infinity, alignment: .leading)

            if vm.notchState == .open && vm.hasNotch {
                Color.clear
                    .frame(width: vm.closedNotchSize.width)
            }

            HStack(spacing: 6) {
                if vm.notchState == .open {
                    if isOSDType(coordinator.sneakPeekState(for: vm.screenUUID).type)
                        && coordinator.shouldShowSneakPeek(on: vm.screenUUID)
                        && Defaults[.showOpenNotchOSD] {
                        OpenNotchOSD(
                            type: coordinator.binding(for: vm.screenUUID).type,
                            value: coordinator.binding(for: vm.screenUUID).value,
                            icon: coordinator.binding(for: vm.screenUUID).icon,
                            accent: coordinator.binding(for: vm.screenUUID).accent
                        )
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        if Defaults[.showMirror] && coordinator.currentView == .home {
                            HeaderIconButton(
                                icon: "web.camera",
                                tooltip: "Camera Preview",
                                isActive: vm.camera.state == .running,
                                action: {
                                    vm.toggleCameraPreview()
                                }
                            )
                        }

                        if Defaults[.settingsIconInNotch] {
                            HeaderIconButton(
                                icon: "gear",
                                tooltip: "Settings",
                                action: {
                                    DispatchQueue.main.async {
                                        SettingsWindowController.shared.showWindow()
                                    }
                                }
                            )
                        }

                        if Defaults[.showBatteryIndicator] {
                            BoringBatteryView(
                                batteryWidth: 24,
                                isCharging: batteryModel.isCharging,
                                isInLowPowerMode: batteryModel.isInLowPowerMode,
                                isPluggedIn: batteryModel.isPluggedIn,
                                levelBattery: batteryModel.levelBattery,
                                maxCapacity: batteryModel.maxCapacity,
                                timeToFullCharge: batteryModel.timeToFullCharge,
                                timeToDischarge: batteryModel.timeToDischarge,
                                maxAdapterWatts: batteryModel.maxAdapterWatts,
                                isForNotification: false
                            )
                        }
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
    }

    func isOSDType(_ type: SneakContentType) -> Bool {
        switch type {
        case .volume, .brightness, .backlight, .mic:
            return true
        default:
            return false
        }
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel(camera: CameraModel()))
}
