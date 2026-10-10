//
//  NetworkManager.swift
//  Crenelle
//
//  Samples per interface byte counters. Created 2026-10-10 by Ian L.
//

import Darwin
import Foundation

struct NetworkInterface: Identifiable, Equatable {
    let id: String
    let name: String
    let received: UInt64
    let sent: UInt64
}

@MainActor
final class NetworkManager: ObservableObject {
    static let shared = NetworkManager()

    @Published private(set) var downloadSpeed: Double = 0
    @Published private(set) var uploadSpeed: Double = 0
    @Published private(set) var downloadHistory: [Double] = []
    @Published private(set) var uploadHistory: [Double] = []
    @Published private(set) var interfaces: [NetworkInterface] = []
    @Published private(set) var totalReceived: UInt64 = 0
    @Published private(set) var totalSent: UInt64 = 0

    private let historyLength = 60
    private var timer: Timer?
    private var lastSample: Date?
    private var lastRx: UInt32 = 0
    private var lastTx: UInt32 = 0
    private var hasPrevious = false

    private init() {}

    func start() {
        guard timer == nil else { sample(); return }
        sample()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        let now = Date()
        let (rx32, tx32, interfaces) = readCounters()
        self.interfaces = interfaces
        totalReceived = UInt64(rx32)
        totalSent = UInt64(tx32)

        defer {
            lastSample = now
            lastRx = rx32
            lastTx = tx32
            hasPrevious = true
        }

        guard hasPrevious, let previous = lastSample else { return }
        let interval = now.timeIntervalSince(previous)
        guard interval > 0 else { return }

        let receivedDelta = UInt64(rx32 &- lastRx)
        let sentDelta = UInt64(tx32 &- lastTx)
        downloadSpeed = Double(receivedDelta) / interval
        uploadSpeed = Double(sentDelta) / interval

        push(downloadSpeed, into: &downloadHistory)
        push(uploadSpeed, into: &uploadHistory)
    }

    private func push(_ value: Double, into history: inout [Double]) {
        history.append(max(value, 0))
        if history.count > historyLength {
            history.removeFirst(history.count - historyLength)
        }
    }

    private func readCounters() -> (UInt32, UInt32, [NetworkInterface]) {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0 else { return (0, 0, []) }
        defer { freeifaddrs(addrs) }

        var rx: UInt32 = 0
        var tx: UInt32 = 0
        var list: [NetworkInterface] = []

        var pointer = addrs
        while let current = pointer {
            let ifa = current.pointee
            let name = String(cString: ifa.ifa_name)
            if ifa.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), let data = ifa.ifa_data {
                let stats = data.assumingMemoryBound(to: if_data.self).pointee
                if !name.hasPrefix("lo") {
                    let received = UInt64(stats.ifi_ibytes)
                    let sent = UInt64(stats.ifi_obytes)
                    list.append(NetworkInterface(id: name, name: name, received: received, sent: sent))
                    rx = rx &+ stats.ifi_ibytes
                    tx = tx &+ stats.ifi_obytes
                }
            }
            pointer = ifa.ifa_next
        }

        list = list
            .filter { $0.received > 0 || $0.sent > 0 }
            .sorted { ($0.received + $0.sent) > ($1.received + $1.sent) }
        return (rx, tx, list)
    }

    static func formatSpeed(_ bytesPerSecond: Double) -> String {
        let value = max(bytesPerSecond, 0)
        switch value {
        case 1_000_000_000...:
            return String(format: "%.1f GB/s", value / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1f MB/s", value / 1_000_000)
        case 1_000...:
            return String(format: "%.0f KB/s", value / 1_000)
        default:
            return String(format: "%.0f B/s", value)
        }
    }
}
