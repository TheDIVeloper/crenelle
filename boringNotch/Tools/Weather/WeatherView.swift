//
//  WeatherView.swift
//  Crenelle
//
//  Weather tab. Created 2026-10-10 by Ian L.
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
            .padding(.vertical, 12)
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
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: WeatherCode.symbol(for: snapshot.weatherCode, isDay: snapshot.isDay))
                    .font(.system(size: 48))
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 56)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(unit.temperature(snapshot.temperature))°")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(WeatherCode.description(for: snapshot.weatherCode))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if let place = manager.placeName {
                        Text(place)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 8)
                detailColumn(snapshot)
            }

            HStack(spacing: 10) {
                unitPicker
                Spacer()
                Button {
                    manager.refresh(force: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Text("Updated \(snapshot.fetchedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func detailColumn(_ snapshot: WeatherSnapshot) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            detail("arrow.up", "\(unit.temperature(snapshot.high))°")
            detail("arrow.down", "\(unit.temperature(snapshot.low))°")
            detail("humidity.fill", "\(Int(snapshot.humidity.rounded()))%")
            detail("wind", "\(unit.wind(snapshot.windSpeed)) \(unit.windUnit)")
        }
    }

    private func detail(_ symbol: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.white)
        }
    }

    private var unitPicker: some View {
        Picker("Unit", selection: $unitRaw) {
            ForEach(TemperatureUnit.allCases) { option in
                Text(option.symbol).tag(option.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 108)
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
