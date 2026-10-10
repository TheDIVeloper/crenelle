//
//  DiskManager.swift
//  Crenelle
//
//  Lists mounted volumes and ejects removable media. Created 2026-10-10 by Ian L.
//

import AppKit
import Combine
import Foundation

struct DiskVolume: Identifiable, Equatable {
    let id: String
    let url: URL
    let name: String
    let totalBytes: Int64
    let freeBytes: Int64
    let isEjectable: Bool
    let isRemovable: Bool
    let isInternal: Bool

    var usedBytes: Int64 { max(totalBytes - freeBytes, 0) }

    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }

    var hasSize: Bool { totalBytes > 0 }
}

@MainActor
final class DiskManager: ObservableObject {
    static let shared = DiskManager()

    @Published private(set) var volumes: [DiskVolume] = []
    @Published var lastError: String?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification,
        ]
        for name in names {
            center.publisher(for: name)
                .sink { [weak self] _ in
                    Task { @MainActor in self?.refresh() }
                }
                .store(in: &cancellables)
        }
        refresh()
    }

    func refresh() {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsEjectableKey,
            .volumeIsRemovableKey,
            .volumeIsInternalKey,
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else {
            volumes = []
            return
        }

        volumes = urls.compactMap { url -> DiskVolume? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = Int64(values.volumeAvailableCapacity ?? 0)
            return DiskVolume(
                id: url.absoluteString,
                url: url,
                name: values.volumeName ?? url.lastPathComponent,
                totalBytes: total,
                freeBytes: free,
                isEjectable: values.volumeIsEjectable ?? false,
                isRemovable: values.volumeIsRemovable ?? false,
                isInternal: values.volumeIsInternal ?? false
            )
        }
        .sorted { lhs, rhs in
            if lhs.isInternal != rhs.isInternal { return lhs.isInternal }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func eject(_ volume: DiskVolume) {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
            lastError = nil
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func reveal(_ volume: DiskVolume) {
        NSWorkspace.shared.activateFileViewerSelecting([volume.url])
    }

    static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
