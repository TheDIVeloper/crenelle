//
//  WeatherManager.swift
//  Crenelle
//
//  Fetches local weather from Open-Meteo (no API key) using CoreLocation.
//  Created 2026-10-10 by Ian L.
//

import CoreLocation
import Foundation

@MainActor
final class WeatherManager: NSObject, ObservableObject {
    static let shared = WeatherManager()

    enum Status: Equatable {
        case idle
        case loading
        case needsLocation
        case denied
        case failed(String)
        case ready
    }

    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var status: Status = .idle
    @Published private(set) var placeName: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastCoordinate: CLLocationCoordinate2D?
    private var lastFetch: Date?
    private var isFetching = false

    private let staleAfter: TimeInterval = 10 * 60

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    // MARK: - Public

    func refresh(force: Bool = false) {
        if !force, let last = lastFetch, Date().timeIntervalSince(last) < staleAfter, snapshot != nil {
            return
        }

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let coordinate = lastCoordinate {
                Task { await fetch(for: coordinate) }
            } else {
                status = snapshot == nil ? .loading : status
                locationManager.requestLocation()
            }
        case .notDetermined:
            if snapshot == nil { status = .needsLocation }
        case .denied, .restricted:
            if snapshot == nil { status = .denied }
        @unknown default:
            if snapshot == nil { status = .denied }
        }
    }

    func requestAuthorization() {
        status = .loading
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Location handling

    fileprivate func handleAuthorizationChange(_ authorization: CLAuthorizationStatus) {
        switch authorization {
        case .authorizedAlways, .authorizedWhenInUse:
            if lastCoordinate == nil {
                status = snapshot == nil ? .loading : status
                locationManager.requestLocation()
            }
        case .denied, .restricted:
            if snapshot == nil { status = .denied }
        case .notDetermined:
            if snapshot == nil { status = .needsLocation }
        @unknown default:
            break
        }
    }

    fileprivate func handleLocation(_ coordinate: CLLocationCoordinate2D) {
        lastCoordinate = coordinate
        Task {
            await reverseGeocode(coordinate)
            await fetch(for: coordinate)
        }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            placeName = placemark.locality
                ?? placemark.subAdministrativeArea
                ?? placemark.administrativeArea
                ?? placemark.country
        }
    }

    // MARK: - Networking

    private func fetch(for coordinate: CLLocationCoordinate2D) async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        if snapshot == nil { status = .loading }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m"
            ),
            URLQueryItem(
                name: "hourly",
                value: "temperature_2m,precipitation_probability,weather_code,is_day"
            ),
            URLQueryItem(
                name: "daily",
                value: "temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max"
            ),
            URLQueryItem(name: "forecast_days", value: "2"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]

        guard let url = components?.url else {
            status = .failed(String(localized: "Could not build the weather request."))
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            var hourlyItems: [HourlyForecastItem] = []
            if let hourly = response.hourly {
                let currentTime = response.current.time
                var startIndex = 0
                for (idx, timeStr) in hourly.time.enumerated() {
                    if timeStr >= currentTime {
                        startIndex = idx
                        break
                    }
                }

                let endIndex = min(startIndex + 12, hourly.time.count)
                for idx in startIndex..<endIndex {
                    let timeStr = hourly.time[idx]
                    let label = idx == startIndex ? String(localized: "Now") : Self.formatHour(from: timeStr)
                    let temp = idx < hourly.temperature_2m.count ? hourly.temperature_2m[idx] : response.current.temperature_2m
                    let code = idx < hourly.weather_code.count ? hourly.weather_code[idx] : response.current.weather_code
                    let prob = (hourly.precipitation_probability != nil && idx < hourly.precipitation_probability!.count) ? hourly.precipitation_probability![idx] : 0
                    let dayVal = idx < hourly.is_day.count ? hourly.is_day[idx] : 1

                    hourlyItems.append(HourlyForecastItem(
                        id: timeStr,
                        timeLabel: label,
                        temperature: temp,
                        weatherCode: code,
                        precipitationProbability: prob,
                        isDay: dayVal == 1
                    ))
                }
            }

            let sunriseFormatted = Self.formatSunTime(from: response.daily.sunrise?.first)
            let sunsetFormatted = Self.formatSunTime(from: response.daily.sunset?.first)
            let uv = response.daily.uv_index_max?.first

            snapshot = WeatherSnapshot(
                temperature: response.current.temperature_2m,
                apparentTemperature: response.current.apparent_temperature,
                humidity: response.current.relative_humidity_2m,
                windSpeed: response.current.wind_speed_10m,
                weatherCode: response.current.weather_code,
                isDay: response.current.is_day == 1,
                high: response.daily.temperature_2m_max.first ?? response.current.temperature_2m,
                low: response.daily.temperature_2m_min.first ?? response.current.temperature_2m,
                precipitation: response.current.precipitation ?? 0.0,
                sunrise: sunriseFormatted,
                sunset: sunsetFormatted,
                uvIndex: uv,
                hourly: hourlyItems,
                fetchedAt: .now
            )
            lastFetch = .now
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private static func formatHour(from isoString: String) -> String {
        let parts = isoString.split(separator: "T")
        guard parts.count == 2 else { return isoString }
        let timeParts = parts[1].split(separator: ":")
        guard let hour24 = Int(timeParts[0]) else { return String(parts[1]) }
        let ampm = hour24 < 12 ? "AM" : "PM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return "\(hour12) \(ampm)"
    }

    private static func formatSunTime(from isoString: String?) -> String? {
        guard let isoString else { return nil }
        let parts = isoString.split(separator: "T")
        guard parts.count == 2 else { return isoString }
        let timeParts = parts[1].split(separator: ":")
        guard timeParts.count >= 2, let hour24 = Int(timeParts[0]) else { return String(parts[1]) }
        let ampm = hour24 < 12 ? "AM" : "PM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return "\(hour12):\(timeParts[1]) \(ampm)"
    }
}

extension WeatherManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorization = manager.authorizationStatus
        MainActor.assumeIsolated {
            handleAuthorizationChange(authorization)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        MainActor.assumeIsolated {
            handleLocation(coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            if snapshot == nil {
                status = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Open-Meteo response

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let time: String
        let temperature_2m: Double
        let relative_humidity_2m: Double
        let apparent_temperature: Double
        let is_day: Int
        let precipitation: Double?
        let weather_code: Int
        let wind_speed_10m: Double
    }

    struct Daily: Decodable {
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let sunrise: [String]?
        let sunset: [String]?
        let uv_index_max: [Double]?
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let precipitation_probability: [Int]?
        let weather_code: [Int]
        let is_day: [Int]
    }

    let current: Current
    let daily: Daily
    let hourly: Hourly?
}
