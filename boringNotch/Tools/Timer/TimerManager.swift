//
//  TimerManager.swift
//  Crenelle
//
//  Countdown timer and stopwatch, shared app-wide so a running timer keeps
//  ticking even when the notch is closed. Created 2026-10-10 by Ian L.
//

import AppKit
import Foundation

@MainActor
final class TimerManager: ObservableObject {
    static let shared = TimerManager()

    enum Mode: String, CaseIterable, Identifiable {
        case countdown
        case stopwatch

        var id: Self { self }

        var label: String {
            switch self {
            case .countdown: return String(localized: "Timer")
            case .stopwatch: return String(localized: "Stopwatch")
            }
        }
    }

    @Published var mode: Mode = .countdown
    @Published private(set) var isRunning = false
    @Published private(set) var isFinished = false

    /// Countdown state.
    @Published private(set) var duration: TimeInterval = 5 * 60
    @Published private(set) var remaining: TimeInterval = 5 * 60

    /// Stopwatch state.
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var laps: [TimeInterval] = []

    private var countdownEndsAt: Date?
    private var lastResume: Date?
    private var ticker: Task<Void, Never>?

    private init() {}

    // MARK: - Controls

    func start() {
        guard !isRunning else { return }
        isFinished = false
        isRunning = true

        switch mode {
        case .countdown:
            if remaining <= 0 { remaining = duration }
            countdownEndsAt = Date.now.addingTimeInterval(remaining)
        case .stopwatch:
            lastResume = .now
        }
        startTicker()
    }

    func pause() {
        guard isRunning else { return }
        captureProgress()
        isRunning = false
        stopTicker()
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func reset() {
        stopTicker()
        isRunning = false
        isFinished = false
        countdownEndsAt = nil
        lastResume = nil
        remaining = duration
        elapsed = 0
        laps.removeAll()
    }

    func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        reset()
        mode = newMode
    }

    func setDuration(_ seconds: TimeInterval) {
        let clamped = min(max(seconds, 60), 180 * 60)
        duration = clamped
        if mode == .countdown, !isRunning {
            remaining = clamped
            isFinished = false
        }
    }

    func addLap() {
        guard mode == .stopwatch, isRunning else { return }
        laps.insert(elapsed, at: 0)
    }

    // MARK: - Ticking

    private func startTicker() {
        stopTicker()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func captureProgress() {
        switch mode {
        case .countdown:
            if let end = countdownEndsAt {
                remaining = max(0, end.timeIntervalSinceNow)
            }
            countdownEndsAt = nil
        case .stopwatch:
            if let last = lastResume {
                elapsed += Date.now.timeIntervalSince(last)
            }
            lastResume = nil
        }
    }

    private func tick() {
        guard isRunning else { return }
        switch mode {
        case .countdown:
            guard let end = countdownEndsAt else { return }
            remaining = max(0, end.timeIntervalSinceNow)
            if remaining <= 0 { finish() }
        case .stopwatch:
            guard let last = lastResume else { return }
            let now = Date.now
            elapsed += now.timeIntervalSince(last)
            lastResume = now
        }
    }

    private func finish() {
        remaining = 0
        isRunning = false
        isFinished = true
        stopTicker()
        NSSound(named: "Glass")?.play()
    }
}

extension TimeInterval {
    /// Formats as m:ss, or h:mm:ss once past an hour.
    var timerDisplay: String {
        let total = Int(rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
