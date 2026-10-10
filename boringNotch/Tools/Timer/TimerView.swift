//
//  TimerView.swift
//  Crenelle
//
//  Timer and stopwatch tab. Created 2026-10-10 by Ian L.
//

import SwiftUI

struct TimerView: View {
    @ObservedObject private var timer = TimerManager.shared

    private let presets: [TimeInterval] = [60, 180, 300, 600, 900, 1500, 2700, 3600]

    private var modeBinding: Binding<TimerManager.Mode> {
        Binding(get: { timer.mode }, set: { timer.setMode($0) })
    }

    private var display: String {
        timer.mode == .countdown ? timer.remaining.timerDisplay : timer.elapsed.timerDisplay
    }

    var body: some View {
        VStack(spacing: 14) {
            Picker("Mode", selection: modeBinding) {
                ForEach(TimerManager.Mode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 260)

            Text(display)
                .font(.system(size: 46, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(timer.isFinished ? Color.orange : .white)
                .contentTransition(.numericText())
                .animation(.smooth, value: display)

            if timer.mode == .countdown {
                countdownControls
            }

            controlsRow

            if timer.mode == .stopwatch, !timer.laps.isEmpty {
                lapsList
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    private var countdownControls: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(presets, id: \.self) { preset in
                        PresetChip(
                            label: preset.timerDisplay,
                            selected: timer.duration == preset
                        ) {
                            timer.reset()
                            timer.setDuration(preset)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack(spacing: 12) {
                StepperButton(systemName: "minus") { timer.setDuration(timer.duration - 60) }
                Text(timer.duration.timerDisplay)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 54)
                StepperButton(systemName: "plus") { timer.setDuration(timer.duration + 60) }
            }
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            Button(action: timer.toggle) {
                Text(startLabel)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .frame(minWidth: 88)
            }
            .buttonStyle(.borderedProminent)
            .tint(timer.isRunning ? .gray : .accentColor)

            Button(action: timer.reset) {
                Text("Reset")
                    .font(.system(.body, design: .rounded))
                    .frame(minWidth: 66)
            }
            .buttonStyle(.bordered)
            .disabled(!timer.isRunning && !timer.isFinished && timer.remaining == timer.duration && timer.elapsed == 0)

            if timer.mode == .stopwatch {
                Button(action: timer.addLap) {
                    Text("Lap")
                        .font(.system(.body, design: .rounded))
                        .frame(minWidth: 54)
                }
                .buttonStyle(.bordered)
                .disabled(!timer.isRunning)
            }
        }
    }

    private var startLabel: String {
        if timer.isRunning { return String(localized: "Pause") }
        if timer.isFinished { return String(localized: "Restart") }
        switch timer.mode {
        case .countdown:
            return timer.remaining < timer.duration ? String(localized: "Resume") : String(localized: "Start")
        case .stopwatch:
            return timer.elapsed > 0 ? String(localized: "Resume") : String(localized: "Start")
        }
    }

    private var lapsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(timer.laps.enumerated()), id: \.offset) { index, lap in
                HStack {
                    Text("Lap \(timer.laps.count - index)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(lap.timerDisplay)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
        .frame(maxWidth: 320)
    }
}

private struct PresetChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(selected ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.08))
                )
                .foregroundStyle(selected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct StepperButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}
