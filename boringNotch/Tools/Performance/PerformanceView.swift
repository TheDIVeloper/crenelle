//
//  PerformanceView.swift
//  Crenelle
//
//  Performance tab. Created 2026-10-10 by Ian L.
//

import SwiftUI

struct PerformanceView: View {
    @ObservedObject private var manager = PerformanceManager.shared

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                metricCard(
                    title: "CPU",
                    icon: "cpu",
                    value: "\(Int((manager.cpuUsage * 100).rounded()))%",
                    history: manager.cpuHistory,
                    tint: tint(for: manager.cpuUsage)
                )
                metricCard(
                    title: "Memory",
                    icon: "memorychip",
                    value: "\(Int((manager.memoryFraction * 100).rounded()))%",
                    history: manager.memoryHistory,
                    tint: tint(for: manager.memoryFraction),
                    subtitle: "\(DiskManager.format(Int64(manager.memoryUsed))) of \(DiskManager.format(Int64(manager.memoryTotal)))"
                )
            }

            HStack(spacing: 10) {
                infoChip(
                    icon: "square.stack.3d.up",
                    title: "GPU",
                    value: manager.gpuUsage.map { "\(Int($0.rounded()))%" } ?? "n/a"
                )
                infoChip(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Load",
                    value: manager.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: "  ")
                )
                infoChip(
                    icon: "clock",
                    title: "Uptime",
                    value: uptimeText
                )
            }

            if !manager.perCore.isEmpty {
                coreGrid
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .onAppear { manager.start() }
        .onDisappear { manager.stop() }
    }

    private func metricCard(
        title: String,
        icon: String,
        value: String,
        history: [Double],
        tint: Color,
        subtitle: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            Sparkline(values: history, color: tint)
                .frame(height: 38)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private func infoChip(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private var coreGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 16), spacing: 4)], spacing: 4) {
            ForEach(Array(manager.perCore.enumerated()), id: \.offset) { _, usage in
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(tint(for: usage))
                            .frame(height: max(geometry.size.height * usage, usage > 0 ? 2 : 0))
                    }
                }
                .frame(height: 20)
            }
        }
        .padding(.top, 2)
    }

    private var uptimeText: String {
        let total = Int(manager.uptime)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func tint(for value: Double) -> Color {
        switch value {
        case ..<0.6: return .green
        case ..<0.85: return .yellow
        default: return .red
        }
    }
}

struct Sparkline: View {
    let values: [Double]
    var color: Color

    var body: some View {
        GeometryReader { geometry in
            let points = points(in: geometry.size)
            ZStack {
                if points.count > 1, let first = points.first, let last = points.last {
                    Path { path in
                        path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                        path.addLine(to: first)
                        path.addLines(points)
                        path.addLine(to: CGPoint(x: last.x, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.15))

                    Path { path in path.addLines(points) }
                        .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, size.width > 0 else { return [] }
        let step = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { index, value in
            let clamped = min(max(value, 0), 1)
            return CGPoint(x: CGFloat(index) * step, y: size.height * (1 - CGFloat(clamped)))
        }
    }
}
