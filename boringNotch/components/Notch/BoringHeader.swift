//
//  BoringHeader.swift
//  boringNotch
//
//  Created by Harsh Vardhan Goswami on 04/08/24.
//

import Defaults
import SwiftUI

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
            // Flexible leading spacer balances the trailing controls and keeps
            // the hardware notch spacer precisely centred on notched screens.
            Spacer(minLength: 0)
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
