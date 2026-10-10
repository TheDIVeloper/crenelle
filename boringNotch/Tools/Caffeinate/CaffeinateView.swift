//
//  CaffeinateView.swift
//  Crenelle
//
//  Caffeinate tab. Created 2026-10-10 by Ian L.
//

import SwiftUI

struct CaffeinateView: View {
    @ObservedObject private var manager = CaffeinateManager.shared

    var body: some View {
        VStack(spacing: 14) {
            header

            VStack(spacing: 8) {
                Text("Keep awake for")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    ForEach(CaffeinateDuration.allCases) { duration in
                        durationButton(duration)
                    }
                }
            }

            Toggle("Keep the display on too", isOn: displayBinding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.callout)
                .foregroundStyle(.white)
                .disabled(!manager.isActive)

            Text("Closing the lid may still put the Mac to sleep depending on your power settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let error = manager.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(manager.isActive ? Color.orange.opacity(0.25) : Color.white.opacity(0.08))
                    .frame(width: 46, height: 46)
                Image(systemName: manager.isActive ? "cup.and.saucer.fill" : "moon.zzz.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(manager.isActive ? .orange : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(manager.isActive ? "Keeping the Mac awake" : "Not caffeinated")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            if manager.isActive {
                Button("Stop") { manager.deactivate() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)
            }
        }
    }

    private func durationButton(_ duration: CaffeinateDuration) -> some View {
        Button {
            manager.activate(keepDisplayOn: manager.keepDisplayOn, duration: duration)
        } label: {
            Text(duration.label)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            manager.selectedDuration == duration
                ? Color.orange.opacity(0.5)
                : Color.white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private var displayBinding: Binding<Bool> {
        Binding(
            get: { manager.keepDisplayOn },
            set: { manager.setKeepDisplayOn($0) }
        )
    }

    private var statusDetail: String {
        guard manager.isActive else { return "Choose a duration to begin" }
        guard manager.endDate != nil else { return "Indefinitely until you stop" }
        return "\(formatRemaining(manager.remaining)) remaining"
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
