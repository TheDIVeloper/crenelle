//
//  NetworkView.swift
//  Crenelle
//
//  Network tab. Created 2026-10-10 by Ian L.
//

import SwiftUI

struct NetworkView: View {
    @ObservedObject private var manager = NetworkManager.shared

    var body: some View {
        VStack(spacing: 10) {
            speedRow(
                title: "Download",
                icon: "arrow.down.circle.fill",
                tint: .blue,
                speed: manager.downloadSpeed,
                history: manager.downloadHistory
            )
            speedRow(
                title: "Upload",
                icon: "arrow.up.circle.fill",
                tint: .green,
                speed: manager.uploadSpeed,
                history: manager.uploadHistory
            )

            HStack(spacing: 10) {
                infoChip(icon: "arrow.down", title: "Received", value: DiskManager.format(Int64(manager.totalReceived)))
                infoChip(icon: "arrow.up", title: "Sent", value: DiskManager.format(Int64(manager.totalSent)))
            }

            if !manager.interfaces.isEmpty {
                interfacesList
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .onAppear { manager.start() }
        .onDisappear { manager.stop() }
    }

    private func speedRow(
        title: String,
        icon: String,
        tint: Color,
        speed: Double,
        history: [Double]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                Spacer()
                Text(NetworkManager.formatSpeed(speed))
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            Sparkline(values: normalized(history), color: tint)
                .frame(height: 34)
        }
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private func infoChip(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private var interfacesList: some View {
        VStack(spacing: 4) {
            ForEach(manager.interfaces) { interface in
                HStack(spacing: 8) {
                    Text(interface.name)
                        .font(.caption.weight(.medium).monospaced())
                        .foregroundStyle(.white)
                    Spacer()
                    Label(DiskManager.format(Int64(interface.received)), systemImage: "arrow.down")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                    Label(DiskManager.format(Int64(interface.sent)), systemImage: "arrow.up")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func normalized(_ history: [Double]) -> [Double] {
        let peak = max(history.max() ?? 0, 1)
        return history.map { $0 / peak }
    }
}
