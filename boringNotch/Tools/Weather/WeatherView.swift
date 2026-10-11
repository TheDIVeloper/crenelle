//
//  WeatherView.swift
//  Crenelle
//
//  Redesigned weather tab with hero overview, metric grid, and hourly timeline.
//  Created 2026-10-10 by Ian L.
//

import Combine
import SwiftUI

struct WeatherView: View {
    @ObservedObject private var manager = WeatherManager.shared
    @AppStorage("weatherUnit") private var unitRaw: String = TemperatureUnit.celsius.rawValue

    private var unit: TemperatureUnit {
        TemperatureUnit(rawValue: unitRaw) ?? .celsius
    }

    private let timer = Timer.publish(every: 600, on: .main, in: .common).autoconnect()

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .task { manager.refresh() }
            .onReceive(timer) { _ in manager.refresh(force: true) }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = manager.snapshot {
            ready(snapshot)
        } else {
            switch manager.status {
            case .loading, .idle, .ready:
                ProgressView().controlSize(.small).frame(height: 120)
            case .needsLocation:
                message(
                    icon: "location.circle",
                    title: "Weather needs your location",
                    detail: "Allow location access to show the local forecast.",
                    actionTitle: "Allow"
                ) { manager.requestAuthorization() }
            case .denied:
                message(
                    icon: "location.slash",
                    title: "Location access is off",
                    detail: "Turn on Location Services for Crenelle in System Settings.",
                    actionTitle: "Open Settings"
                ) { openLocationSettings() }
            case .failed(let reason):
                message(
                    icon: "exclamationmark.triangle",
                    title: "Could not load weather",
                    detail: reason,
                    actionTitle: "Retry"
                ) { manager.refresh(force: true) }
            }
        }
    }

    private func ready(_ snapshot: WeatherSnapshot) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                heroCard(snapshot)
                    .frame(width: 220)

                metricGrid(snapshot)
            }

            if !snapshot.hourly.isEmpty {
                hourlySection(snapshot)
            }

            footer(snapshot)
        }
    }

    private func heroCard(_ snapshot: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(manager.placeName ?? "Current Location")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                unitPicker
            }

            HStack(spacing: 12) {
                Image(systemName: WeatherCode.symbol(for: snapshot.weatherCode, isDay: snapshot.isDay))
                    .font(.system(size: 38))
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(unit.temperature(snapshot.temperature))°")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(WeatherCode.description(for: snapshot.weatherCode))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }

            HStack(spacing: 6) {
                Text("↑ \(unit.temperature(snapshot.high))°  ↓ \(unit.temperature(snapshot.low))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let sunTime = snapshot.isDay ? snapshot.sunset : snapshot.sunrise {
                    HStack(spacing: 3) {
                        Image(systemName: snapshot.isDay ? "sunset.fill" : "sunrise.fill")
                            .font(.system(size: 10))
                            .symbolRenderingMode(.multicolor)
                        Text(sunTime)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func metricGrid(_ snapshot: WeatherSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 8) {
            metricTile(
                icon: "thermometer.medium",
                title: "FEELS LIKE",
                value: "\(unit.temperature(snapshot.apparentTemperature))°",
                subtitle: apparentSubtitle(snapshot)
            )

            metricTile(
                icon: "cloud.rain.fill",
                title: "PRECIPITATION",
                value: snapshot.precipitation > 0 ? String(format: "%.1f mm", snapshot.precipitation) : "\(snapshot.hourly.first?.precipitationProbability ?? 0)%",
                subtitle: snapshot.precipitation > 0 ? "Observed" : "Rain chance"
            )

            metricTile(
                icon: "humidity.fill",
                title: "HUMIDITY",
                value: "\(Int(snapshot.humidity.rounded()))%",
                subtitle: humiditySubtitle(snapshot.humidity)
            )

            metricTile(
                icon: "wind",
                title: "WIND",
                value: "\(unit.wind(snapshot.windSpeed)) \(unit.windUnit)",
                subtitle: windSubtitle(snapshot.windSpeed)
            )
        }
    }

    private func metricTile(
        icon: String,
        title: String,
        value: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func hourlySection(_ snapshot: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("HOURLY FORECAST")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(snapshot.hourly) { item in
                        hourlyTile(item)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func hourlyTile(_ item: HourlyForecastItem) -> some View {
        VStack(spacing: 4) {
            Text(item.timeLabel)
                .font(.system(size: 10, weight: item.timeLabel == "Now" ? .bold : .medium))
                .foregroundStyle(item.timeLabel == "Now" ? .white : .secondary)

            Image(systemName: WeatherCode.symbol(for: item.weatherCode, isDay: item.isDay))
                .font(.system(size: 16))
                .symbolRenderingMode(.multicolor)
                .frame(height: 18)

            if item.precipitationProbability >= 15 {
                Text("\(item.precipitationProbability)%")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.cyan)
                    .frame(height: 10)
            } else {
                Color.clear
                    .frame(height: 10)
            }

            Text("\(unit.temperature(item.temperature))°")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 44)
        .padding(.vertical, 5)
        .background {
            if item.timeLabel == "Now" {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
            }
        }
    }

    private func apparentSubtitle(_ snapshot: WeatherSnapshot) -> String {
        let diff = abs(snapshot.apparentTemperature - snapshot.temperature)
        if diff < 1.5 {
            return "Similar to actual"
        } else if snapshot.apparentTemperature < snapshot.temperature {
            return "Feels cooler"
        } else {
            return "Feels warmer"
        }
    }

    private func humiditySubtitle(_ humidity: Double) -> String {
        if humidity >= 70 {
            return "High humidity"
        } else if humidity <= 30 {
            return "Dry air"
        } else {
            return "Comfortable"
        }
    }

    private func windSubtitle(_ speed: Double) -> String {
        if speed < 12 {
            return "Gentle breeze"
        } else if speed < 28 {
            return "Moderate breeze"
        } else {
            return "Strong wind"
        }
    }

    private func footer(_ snapshot: WeatherSnapshot) -> some View {
        HStack(spacing: 6) {
            Text("Open-Meteo")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                manager.refresh(force: true)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Text("Updated \(snapshot.fetchedAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 4)
    }

    private var unitPicker: some View {
        Picker("Unit", selection: $unitRaw) {
            ForEach(TemperatureUnit.allCases) { option in
                Text(option.symbol).tag(option.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 76)
        .scaleEffect(0.9)
    }

    private func message(
        icon: String,
        title: String,
        detail: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text(title).font(.headline).foregroundStyle(.white)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func openLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }
}
