//
//  DiskView.swift
//  Crenelle
//
//  Disk tab. Created 2026-10-10 by Ian L.
//

import SwiftUI

struct DiskView: View {
    @ObservedObject private var manager = DiskManager.shared

    var body: some View {
        VStack(spacing: 8) {
            if manager.volumes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(manager.volumes) { volume in
                            row(volume)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.never)
            }

            if let error = manager.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .onAppear { manager.refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "externaldrive")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text("No volumes found")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func row(_ volume: DiskVolume) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: volume))
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(volume.name)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                    if volume.isRemovable || volume.isEjectable {
                        Text("Removable")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.white.opacity(0.12), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                if volume.hasSize {
                    usageBar(volume)
                    Text("\(DiskManager.format(volume.freeBytes)) free of \(DiskManager.format(volume.totalBytes))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                } else {
                    Text("Size unavailable")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            if volume.isEjectable || volume.isRemovable {
                Button {
                    manager.eject(volume)
                } label: {
                    Image(systemName: "eject.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Eject")
            }

            Button {
                manager.reveal(volume)
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func usageBar(_ volume: DiskVolume) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(volume.usedFraction > 0.9 ? Color.red : Color.accentColor)
                    .frame(width: geometry.size.width * volume.usedFraction)
            }
        }
        .frame(height: 4)
    }

    private func icon(for volume: DiskVolume) -> String {
        if volume.isInternal { return "internaldrive" }
        if volume.isRemovable { return "sdcard" }
        return "externaldrive"
    }
}
