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
                value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m"
            ),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]

        guard let url = components?.url else {
            status = .failed(String(localized: "Could not build the weather request."))
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            snapshot = WeatherSnapshot(
                temperature: response.current.temperature_2m,
                apparentTemperature: response.current.apparent_temperature,
                humidity: response.current.relative_humidity_2m,
                windSpeed: response.current.wind_speed_10m,
                weatherCode: response.current.weather_code,
                isDay: response.current.is_day == 1,
                high: response.daily.temperature_2m_max.first ?? response.current.temperature_2m,
                low: response.daily.temperature_2m_min.first ?? response.current.temperature_2m,
                fetchedAt: .now
            )
            lastFetch = .now
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
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
        let temperature_2m: Double
        let relative_humidity_2m: Double
        let apparent_temperature: Double
        let is_day: Int
        let weather_code: Int
        let wind_speed_10m: Double
    }

    struct Daily: Decodable {
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
    }

    let current: Current
    let daily: Daily
}
