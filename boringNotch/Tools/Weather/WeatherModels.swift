//
//  WeatherModels.swift
//  Crenelle
//
//  Weather value types, hourly timeline data, and WMO code mapping. Created 2026-10-10 by Ian L.
//

import Foundation

struct HourlyForecastItem: Identifiable, Equatable {
    let id: String
    let timeLabel: String
    let temperature: Double
    let weatherCode: Int
    let precipitationProbability: Int
    let isDay: Bool
}

struct WeatherSnapshot: Equatable {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Double
    let windSpeed: Double
    let weatherCode: Int
    let isDay: Bool
    let high: Double
    let low: Double
    let precipitation: Double
    let sunrise: String?
    let sunset: String?
    let uvIndex: Double?
    let hourly: [HourlyForecastItem]
    let fetchedAt: Date
}

enum WeatherCode {
    static func symbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1: return isDay ? "sun.max.fill" : "moon.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57, 66, 67: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0: return String(localized: "Clear")
        case 1: return String(localized: "Mainly clear")
        case 2: return String(localized: "Partly cloudy")
        case 3: return String(localized: "Overcast")
        case 45, 48: return String(localized: "Fog")
        case 51, 53, 55: return String(localized: "Drizzle")
        case 56, 57: return String(localized: "Freezing drizzle")
        case 61, 63: return String(localized: "Rain")
        case 65: return String(localized: "Heavy rain")
        case 66, 67: return String(localized: "Freezing rain")
        case 71, 73, 75, 77: return String(localized: "Snow")
        case 80, 81, 82: return String(localized: "Rain showers")
        case 85, 86: return String(localized: "Snow showers")
        case 95: return String(localized: "Thunderstorm")
        case 96, 99: return String(localized: "Thunderstorm with hail")
        default: return String(localized: "Unknown")
        }
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius
    case fahrenheit

    var id: Self { self }

    var symbol: String { self == .celsius ? "°C" : "°F" }

    func convert(_ celsius: Double) -> Double {
        self == .celsius ? celsius : celsius * 9 / 5 + 32
    }

    func format(_ celsius: Double) -> String {
        "\(Int(convert(celsius).rounded()))°"
    }

    func temperature(_ celsius: Double) -> Int {
        Int(convert(celsius).rounded())
    }

    func wind(_ kmh: Double) -> Int {
        self == .celsius ? Int(kmh.rounded()) : Int((kmh * 0.621371).rounded())
    }

    var windUnit: String { self == .celsius ? "km/h" : "mph" }
}
