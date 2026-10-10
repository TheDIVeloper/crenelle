//
//  PerAppMixerView.swift
//  Crenelle
//
//  Sound tab: per-app volume mixer section. Rows come from
//  PerAppMixerManager; apps below 100% get a muted process tap plus a
//  private aggregate device re-rendering them at the chosen gain. Apps
//  at 100% are never touched.
//
//  SPDX-License-Identifier: GPL-3.0-or-later
//
//  Adapted from Vorssaint (github.com/vorssaint/vorssaint-utils),
//  GPL-3.0-or-later, and the aggregate recipe from insidegui/AudioCap
//  (BSD-2-Clause). Ported into Crenelle 2026-10-10 by Ian L.
//

import SwiftUI

struct PerAppMixerView: View {
    @ObservedObject private var manager = PerAppMixerManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle

            if manager.needsPermission {
                permissionBanner
            }

            if manager.rows.isEmpty {
                Text("No apps are playing audio")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.leading, 2)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(manager.rows) { row in
                            self.row(for: row)
                        }
                    }
                }
                .frame(maxHeight: 190)
            }

            if let error = manager.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .onAppear {
            manager.startMonitoring()
        }
    }

    private var sectionTitle: some View {
        HStack(spacing: 6) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Apps")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .padding(.leading, 2)
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("macOS needs the Screen & System Audio Recording permission before an app can be pulled into the mixer.")
                .font(.caption2)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open Privacy Settings") {
                manager.openPrivacySettings()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(for row: PerAppMixerRow) -> some View {
        HStack(spacing: 10) {
            Group {
                if let icon = row.icon {
                    Image(nsImage: icon)
                        .resizable()
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if row.isPlaying {
                        Circle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 5, height: 5)
                    }
                }

                Slider(
                    value: Binding(
                        get: { row.volume },
                        set: { manager.setVolume($0, for: row.id) }
                    ),
                    in: 0...1
                )
                .disabled(!row.hasProcess && row.volume >= PerAppMixerManager.unityVolume)

                HStack {
                    Text("\(Int((row.volume * 100).rounded()))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    if row.volume < PerAppMixerManager.unityVolume {
                        Button("Reset") {
                            manager.resetVolume(for: row.id)
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1))
        }
    }
}
