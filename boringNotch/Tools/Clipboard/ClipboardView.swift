//
//  ClipboardView.swift
//  Crenelle
//
//  Clipboard history tab. Click a row to copy it back as plain text.
//  Created 2026-10-10 by Ian L.
//

import SwiftUI

struct ClipboardView: View {
    @ObservedObject private var manager = ClipboardManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if manager.items.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(manager.items) { item in
                        ClipboardRow(item: item) {
                            withAnimation(.smooth) {
                                manager.copy(item)
                            }
                        } onDelete: {
                            withAnimation(.smooth) {
                                manager.delete(item)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Clipboard")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
            Text("\(manager.items.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            if !manager.items.isEmpty {
                Button {
                    withAnimation(.smooth) { manager.clear() }
                } label: {
                    Text("Clear").font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("Copied text shows up here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.preview)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(item.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if hovered {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(hovered ? 0.10 : 0.05))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .contextMenu {
            Button("Copy") { onCopy() }
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}
