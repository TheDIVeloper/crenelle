//
//  PerformanceManager.swift
//  Crenelle
//
//  Samples CPU, memory and GPU load. Created 2026-10-10 by Ian L.
//

import Darwin
import Foundation
import IOKit

@MainActor
final class PerformanceManager: ObservableObject {
    static let shared = PerformanceManager()

    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var perCore: [Double] = []
    @Published private(set) var memoryUsed: UInt64 = 0
    @Published private(set) var memoryTotal: UInt64 = 0
    @Published private(set) var memoryHistory: [Double] = []
    @Published private(set) var gpuUsage: Double?
    @Published private(set) var loadAverage: [Double] = [0, 0, 0]
    @Published private(set) var uptime: TimeInterval = 0

    private let historyLength = 60
    private var timer: Timer?

    private var previousTicks: [Int32] = []
    private let stateCount = Int(CPU_STATE_MAX)

    private init() {
        memoryTotal = ProcessInfo.processInfo.physicalMemory
    }

    var memoryFraction: Double {
        memoryTotal > 0 ? Double(memoryUsed) / Double(memoryTotal) : 0
    }

    func start() {
        guard timer == nil else { sample(); return }
        sample()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
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
        sampleCPU()
        sampleMemory()
        gpuUsage = sampleGPU()
        var loads = [Double](repeating: 0, count: 3)
        if getloadavg(&loads, 3) == 3 { loadAverage = loads }
        uptime = ProcessInfo.processInfo.systemUptime
    }

    // MARK: - CPU

    private func sampleCPU() {
        var cpuInfo: processor_info_array_t?
        var cpuCount: natural_t = 0
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfo,
            &infoCount
        )
        guard result == KERN_SUCCESS, let cpuInfo else { return }
        defer {
            let size = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }

        var cores: [Double] = []
        var newTicks: [Int32] = []
        var totalActive: Double = 0
        var totalAll: Double = 0

        for core in 0..<Int(cpuCount) {
            let base = core * stateCount
            let user = cpuInfo[base + Int(CPU_STATE_USER)]
            let system = cpuInfo[base + Int(CPU_STATE_SYSTEM)]
            let idle = cpuInfo[base + Int(CPU_STATE_IDLE)]
            let nice = cpuInfo[base + Int(CPU_STATE_NICE)]
            let current = [user, system, idle, nice]
            newTicks.append(contentsOf: current)

            if previousTicks.count >= (base + stateCount) {
                let dUser = Double(user &- previousTicks[base])
                let dSystem = Double(system &- previousTicks[base + 1])
                let dIdle = Double(idle &- previousTicks[base + 2])
                let dNice = Double(nice &- previousTicks[base + 3])
                let active = dUser + dSystem + dNice
                let all = active + dIdle
                cores.append(all > 0 ? active / all : 0)
                totalActive += active
                totalAll += all
            }
        }

        previousTicks = newTicks
        if !cores.isEmpty {
            perCore = cores
            let usage = totalAll > 0 ? totalActive / totalAll : 0
            cpuUsage = usage
            push(usage, into: &cpuHistory)
        }
    }

    // MARK: - Memory

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let size = UInt64(pageSize)
        let active = UInt64(stats.active_count) * size
        let wired = UInt64(stats.wire_count) * size
        let compressed = UInt64(stats.compressor_page_count) * size
        memoryUsed = min(active + wired + compressed, memoryTotal)
        push(memoryFraction, into: &memoryHistory)
    }

    private func push(_ value: Double, into history: inout [Double]) {
        history.append(min(max(value, 0), 1))
        if history.count > historyLength {
            history.removeFirst(history.count - historyLength)
        }
    }

    // MARK: - GPU (best effort)

    private func sampleGPU() -> Double? {
        guard let matching = IOServiceMatching("IOAccelerator") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var maxUtilization: Double?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let unmanaged = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            ), let stats = unmanaged.takeRetainedValue() as? [String: Any] {
                if let value = stats["Device Utilization %"] as? Int {
                    maxUtilization = max(maxUtilization ?? 0, Double(value))
                } else if let value = stats["Device Utilization %"] as? Double {
                    maxUtilization = max(maxUtilization ?? 0, value)
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return maxUtilization
    }
}
