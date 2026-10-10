//
//  generic.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Foundation
import Defaults

enum Style {
    case notch
    case floating
}

enum NotchState {
    case closed
    case open
}

enum NotchViews: CaseIterable, Identifiable, Hashable {
    case home
    case shelf
    // Tools. Declared in the order they should appear in the tab bar.
    case clipboard
    case timer
    case weather
    case sound
    case disk
    case performance
    case network
    case caffeinate

    var id: Self { self }

    /// Tools switched on for the tab bar. A tool is added here only once its
    /// page actually exists, so the bar never advertises a view that has not
    /// shipped yet. Home and Shelf are always available.
    private static let shippedTools: Set<NotchViews> = [.clipboard, .timer, .weather, .disk, .performance]

    var isEnabled: Bool {
        switch self {
        case .home, .shelf:
            return true
        default:
            return Self.shippedTools.contains(self)
        }
    }

    var label: String {
        switch self {
        case .home: return String(localized: "Home")
        case .shelf: return String(localized: "Shelf")
        case .clipboard: return String(localized: "Clipboard")
        case .timer: return String(localized: "Timer")
        case .weather: return String(localized: "Weather")
        case .sound: return String(localized: "Sound")
        case .disk: return String(localized: "Disk")
        case .performance: return String(localized: "Performance")
        case .network: return String(localized: "Network")
        case .caffeinate: return String(localized: "Caffeinate")
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .shelf: return "tray.fill"
        case .clipboard: return "doc.on.clipboard"
        case .timer: return "timer"
        case .weather: return "cloud.sun.fill"
        case .sound: return "speaker.wave.2.fill"
        case .disk: return "externaldrive.fill"
        case .performance: return "gauge.with.dots.needle.bottom.50percent"
        case .network: return "network"
        case .caffeinate: return "cup.and.saucer.fill"
        }
    }
}

enum DownloadIndicatorStyle: String, Defaults.Serializable {
    case progress = "Progress"
    case percentage = "Percentage"
}

enum DownloadIconStyle: String, Defaults.Serializable {
    case onlyAppIcon = "Only app icon"
    case onlyIcon = "Only download icon"
    case iconAndAppIcon = "Icon and app icon"
}

enum MirrorShapeEnum: String, Defaults.Serializable {
    case rectangle = "Rectangular"
    case circle = "Circular"
}

enum WindowHeightMode: String, Defaults.Serializable {
    case matchMenuBar = "Match menu bar height"
    case matchRealNotchSize = "Match real notch height"
    case custom = "Custom height"
}

enum SliderColorEnum: String, CaseIterable, Defaults.Serializable {
    case white
    case albumArt
    case accent

    init?(rawValue: String) {
        switch rawValue {
        case "white", "White": self = .white
        case "albumArt", "Match album art": self = .albumArt
        case "accent", "Accent color": self = .accent
        default: return nil
        }
    }

    var localizedString: String {
        switch self {
        case .white:
            return String(localized: "White", comment: "Slider color option: white")
        case .albumArt:
            return String(localized: "Match album art", comment: "Slider color option: match album art")
        case .accent:
            return String(localized: "Accent color", comment: "Slider color option: accent color")
        }
    }
}

enum WeekStartDay: String, CaseIterable, Identifiable, Defaults.Serializable {
    case system
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: String { rawValue }

    /// Calendar.firstWeekday convention: 1 = Sunday … 7 = Saturday
    var firstWeekday: Int {
        switch self {
        case .system: return Calendar.current.firstWeekday
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    /// Display name. Specific weekdays use the system's localized weekday names
    /// (Apple-provided via Calendar — no custom strings). The system option shows
    /// the resolved first weekday in parentheses, mirroring the macOS Calendar app.
    var localizedString: String {
        let symbols = Calendar.current.weekdaySymbols  // localized full names; index 0 = Sunday
        guard !symbols.isEmpty else { return rawValue }
        if self == .system {
            let systemName = symbols[(Calendar.current.firstWeekday - 1) % symbols.count]
            let label = NSLocalizedString("System Setting", comment: "Week starts on: follow the macOS system setting")
            return "\(label) (\(systemName))"
        }
        return symbols[(firstWeekday - 1) % symbols.count]
    }
}
