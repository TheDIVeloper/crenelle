//
//  CaffeinateManager.swift
//  Crenelle
//
//  Holds an IOKit power assertion to keep the Mac awake. Created 2026-10-10 by Ian L.
//

import Foundation
import IOKit.pwr_mgt

@MainActor
final class CaffeinateManager: ObservableObject {
    static let shared = CaffeinateManager()

    @Published private(set) var isActive = false
    @Published private(set) var keepDisplayOn = false
    @Published private(set) var endDate: Date?
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var selectedDuration: CaffeinateDuration?
    @Published var lastError: String?

    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false
    private var timer: Timer?

    private init() {}

    func activate(keepDisplayOn: Bool, duration: CaffeinateDuration) {
        releaseAssertion()
        self.keepDisplayOn = keepDisplayOn
        self.selectedDuration = duration

        let type = keepDisplayOn
            ? kIOPMAssertionTypePreventUserIdleDisplaySleep
            : kIOPMAssertionTypePreventUserIdleSystemSleep
        let reason = "Crenelle is keeping the Mac awake" as CFString
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &id
        )

        guard result == kIOReturnSuccess else {
            lastError = "Could not create the power assertion (\(result))."
            return
        }

        lastError = nil
        assertionID = id
        hasAssertion = true
        isActive = true

        if let seconds = duration.seconds {
            endDate = Date().addingTimeInterval(seconds)
            remaining = seconds
            startTimer()
        } else {
            endDate = nil
            remaining = 0
            stopTimer()
        }
    }

    func deactivate() {
        releaseAssertion()
        stopTimer()
        isActive = false
        endDate = nil
        remaining = 0
        selectedDuration = nil
    }

    func setKeepDisplayOn(_ keepDisplayOn: Bool) {
        guard isActive else {
            self.keepDisplayOn = keepDisplayOn
            return
        }
        releaseAssertion()
        self.keepDisplayOn = keepDisplayOn

        let type = keepDisplayOn
            ? kIOPMAssertionTypePreventUserIdleDisplaySleep
            : kIOPMAssertionTypePreventUserIdleSystemSleep
        let reason = "Crenelle is keeping the Mac awake" as CFString
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &id
        )
        if result == kIOReturnSuccess {
            assertionID = id
            hasAssertion = true
        } else {
            isActive = false
            lastError = "Could not create the power assertion (\(result))."
        }
    }

    private func releaseAssertion() {
        if hasAssertion {
            IOPMAssertionRelease(assertionID)
            hasAssertion = false
            assertionID = 0
        }
    }

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            deactivate()
        } else {
            remaining = left
        }
    }
}

enum CaffeinateDuration: String, CaseIterable, Identifiable {
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case indefinite

    var id: Self { self }

    var seconds: TimeInterval? {
        switch self {
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .indefinite: return nil
        }
    }

    var label: String {
        switch self {
        case .fifteenMinutes: return "15m"
        case .thirtyMinutes: return "30m"
        case .oneHour: return "1h"
        case .twoHours: return "2h"
        case .indefinite: return "Until I stop"
        }
    }
}
