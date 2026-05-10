// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import FairSkiesModel

/// The "hero" weather view for a single saved location: backdrop gradient, large temperature,
/// hourly forecast strip, daily forecast list, and detail metric cards.
public struct CurrentWeatherView: View {
    @Environment(WeatherStore.self) var store: WeatherStore
    public let location: SavedLocation

    public init(location: SavedLocation) {
        self.location = location
    }

    private var report: WeatherReport? {
        store.report(for: location)
    }

    private var loadState: LoadState {
        store.loadState(for: location)
    }

    private var condition: WeatherCondition {
        report?.current.condition ?? WeatherCondition(code: 0, kind: .clear, isDay: true)
    }

    public var body: some View {
        ZStack {
            store.settings.theme.gradient(for: condition)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 24) {
                    headerSection
                    if let report = report {
                        hourlySection(report: report)
                        dailySection(report: report)
                        detailsSection(report: report)
                        attributionSection
                    } else {
                        loadingOrErrorSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 50)
            }
            .refreshable {
                await store.refresh(location)
            }
        }
        .foregroundStyle(.white)
        .task {
            if report == nil {
                await store.refresh(location)
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 6) {
            Text(location.name)
                .font(.system(size: 34, weight: .semibold))
            if !location.displaySubtitle.isEmpty {
                Text(location.displaySubtitle)
                    .font(.subheadline)
                    .opacity(0.85)
            }
            if let report = report {
                WeatherIcon(condition: report.current.condition,
                            size: 132,
                            animated: store.settings.showAnimations)
                    .padding(.top, 8)
                Text(store.formatter.temperatureString(report.current.temperature))
                    .font(.system(size: 92, weight: .thin))
                    .padding(.top, -4)
                Text(report.current.condition.label)
                    .font(.title3.weight(.medium))
                    .opacity(0.95)
                HStack(spacing: 14) {
                    Text(store.formatter.temperatureString(highToday(report)))
                    Text("\u{2191}")
                    Text(store.formatter.temperatureString(lowToday(report)))
                    Text("\u{2193}")
                }
                .font(.subheadline)
                .opacity(0.9)
                Text("Feels like \(store.formatter.temperatureString(report.current.apparentTemperature))")
                    .font(.subheadline)
                    .opacity(0.85)
            } else if loadState.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .padding(.top, 30)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func hourlySection(report: WeatherReport) -> some View {
        let upcoming = upcomingHourly(report: report, count: 24)
        if !upcoming.isEmpty {
            CardContainer(title: "Hourly Forecast", icon: "schedule_default") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(upcoming) { entry in
                            VStack(spacing: 6) {
                                Text(hourLabel(entry: entry, report: report))
                                    .font(.caption)
                                    .opacity(0.85)
                                WeatherGlyph(condition: entry.condition, size: 30, tint: .white)
                                Text(store.formatter.temperatureString(entry.temperature))
                                    .font(.headline)
                                if entry.precipitationProbability >= 10 {
                                    Text(store.formatter.humidityString(entry.precipitationProbability))
                                        .font(.caption2)
                                        .opacity(0.85)
                                        .foregroundStyle(col("#A0E0FF"))
                                }
                            }
                            .frame(width: 60)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func dailySection(report: WeatherReport) -> some View {
        if !report.daily.isEmpty {
            CardContainer(title: "\(report.daily.count)-Day Forecast", icon: "calendar_default") {
                VStack(spacing: 0) {
                    ForEach(Array(report.daily.enumerated()), id: \.offset) { pair in
                        DailyRow(day: pair.element,
                                 isFirst: pair.offset == 0,
                                 formatter: store.formatter,
                                 timezone: report.location.timezone,
                                 minTemp: dailyExtremes(report: report).low,
                                 maxTemp: dailyExtremes(report: report).high)
                        if pair.offset < report.daily.count - 1 {
                            Divider().background(Color.white.opacity(0.15))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func detailsSection(report: WeatherReport) -> some View {
        let metrics = currentMetrics(report: report)
        // Manual 2-column grid built from VStack-of-HStacks instead of LazyVGrid.
        //
        // Why: SkipUI's LazyVGrid is implemented atop Compose's LazyVerticalGrid,
        // which requires bounded height. When LazyVGrid is nested inside a
        // ScrollView, LazyVGrid's Render() detects the parent vertical scroll and
        // bails on first render (contributing a preference so the parent gives up
        // its scroll). On Android the recovery path leaves the grid with unbounded
        // height inside a non-scrolling Column, so it lays out zero items and the
        // section disappears. iOS's LazyVGrid renders inline against the parent
        // ScrollView and is unaffected.
        let rowCount = (metrics.count + 1) / 2
        VStack(spacing: 12) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: 12) {
                    let leftIndex = row * 2
                    let rightIndex = leftIndex + 1
                    MetricCard(metric: metrics[leftIndex])
                        .frame(maxWidth: .infinity)
                    if rightIndex < metrics.count {
                        MetricCard(metric: metrics[rightIndex])
                            .frame(maxWidth: .infinity)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var attributionSection: some View {
        VStack(spacing: 4) {
            if case .loaded(let date) = loadState {
                Text("Updated \(formattedUpdate(date: date, report: report))")
                    .font(.caption2)
                    .opacity(0.75)
            }
            Text("Weather data by Open-Meteo.com")
                .font(.caption2)
                .opacity(0.75)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var loadingOrErrorSection: some View {
        switch loadState {
        case .loading, .idle:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .padding(40)
        case .failed(let message):
            VStack(spacing: 12) {
                AssetIcon("compass_calibration", size: 36)
                Text("Couldn't load weather")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .opacity(0.85)
                Button {
                    Task { await store.refresh(location) }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 30)
        case .loaded:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private func upcomingHourly(report: WeatherReport, count: Int) -> [HourlyForecast] {
        let now = Date()
        var found: [HourlyForecast] = []
        for entry in report.hourly {
            if entry.time >= now.addingTimeInterval(-1800) && found.count < count {
                found.append(entry)
            }
        }
        if found.isEmpty {
            // Fall back to first N entries if none upcoming.
            for i in 0..<min(count, report.hourly.count) {
                found.append(report.hourly[i])
            }
        }
        return found
    }

    private func hourLabel(entry: HourlyForecast, report: WeatherReport) -> String {
        if abs(entry.time.timeIntervalSince(Date())) < 1800 {
            return "Now"
        }
        return store.formatter.hourString(entry.time, timezoneIdentifier: report.location.timezone)
    }

    private func highToday(_ report: WeatherReport) -> Double {
        if let today = report.daily.first {
            return today.temperatureMax
        }
        return report.current.temperature
    }

    private func lowToday(_ report: WeatherReport) -> Double {
        if let today = report.daily.first {
            return today.temperatureMin
        }
        return report.current.temperature
    }

    private func dailyExtremes(report: WeatherReport) -> (low: Double, high: Double) {
        var low = Double.infinity
        var high = -Double.infinity
        for d in report.daily {
            if d.temperatureMin < low { low = d.temperatureMin }
            if d.temperatureMax > high { high = d.temperatureMax }
        }
        if low == Double.infinity { low = 0 }
        if high == -Double.infinity { high = 0 }
        return (low, high)
    }

    private func formattedUpdate(date: Date, report: WeatherReport?) -> String {
        return store.formatter.clockString(date, timezoneIdentifier: report?.location.timezone)
    }

    private func currentMetrics(report: WeatherReport) -> [Metric] {
        var metrics: [Metric] = []
        let f = store.formatter
        metrics.append(Metric(title: "Feels Like",
                              value: f.temperatureString(report.current.apparentTemperature),
                              icon: "thermostat",
                              accent: temperatureColor(celsius: report.current.apparentTemperature)))
        metrics.append(Metric(title: "Humidity",
                              value: f.humidityString(report.current.relativeHumidity),
                              icon: "humidity_percentage",
                              accent: col("#A0E0FF")))
        metrics.append(Metric(title: "Wind",
                              value: f.windSpeedString(report.current.windSpeed) + " " + f.windDirectionString(report.current.windDirection),
                              icon: "air",
                              accent: col("#C8E6FF")))
        metrics.append(Metric(title: "Pressure",
                              value: f.pressureString(report.current.pressure),
                              icon: "compress",
                              accent: col("#FFD9B0")))
        metrics.append(Metric(title: "UV Index",
                              value: f.uvIndexString(report.current.uvIndex),
                              icon: "wb_sunny",
                              accent: col("#FFE08A")))
        metrics.append(Metric(title: "Cloud Cover",
                              value: f.humidityString(report.current.cloudCover),
                              icon: "cloud",
                              accent: col("#E0EAF4")))
        if let today = report.daily.first {
            if let sunrise = today.sunrise, let sunset = today.sunset {
                metrics.append(Metric(title: "Sunrise",
                                      value: f.clockString(sunrise, timezoneIdentifier: report.location.timezone),
                                      icon: "wb_twilight",
                                      accent: col("#FFC58A")))
                metrics.append(Metric(title: "Sunset",
                                      value: f.clockString(sunset, timezoneIdentifier: report.location.timezone),
                                      icon: "bedtime",
                                      accent: col("#FFB078")))
            }
            metrics.append(Metric(title: "Precip. Today",
                                  value: f.precipitationString(today.precipitationSum),
                                  icon: "water_drop",
                                  accent: col("#A0D8FF")))
        }
        return metrics
    }
}

struct Metric: Hashable {
    var title: String
    var value: String
    var icon: String
    var accent: Color
}

struct MetricCard: View {
    let metric: Metric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                AssetIcon(metric.icon, size: 16, tint: metric.accent)
                Text(metric.title.uppercased())
                    .font(.caption)
                    .opacity(0.85)
            }
            Text(metric.value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct CardContainer<Content: View>: View {
    let title: String
    let icon: String?
    @ViewBuilder var content: () -> Content

    init(title: String, icon: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
                Spacer()
            }
            content()
        }
        .padding(14)
        .background(Color.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct DailyRow: View {
    let day: DailyForecast
    let isFirst: Bool
    let formatter: WeatherFormatter
    let timezone: String?
    let minTemp: Double
    let maxTemp: Double

    var body: some View {
        HStack(spacing: 12) {
            Text(isFirst ? "Today" : formatter.weekdayString(day.date, timezoneIdentifier: timezone))
                .font(.subheadline.weight(.medium))
                .frame(width: 56, alignment: .leading)
            WeatherGlyph(condition: day.condition, size: 26, tint: .white)
                .frame(width: 30)
            if day.precipitationProbabilityMax >= 10 {
                Text(formatter.humidityString(day.precipitationProbabilityMax))
                    .font(.caption)
                    .foregroundStyle(col("#A0E0FF"))
                    .frame(width: 36, alignment: .leading)
            } else {
                Text("")
                    .frame(width: 36)
            }
            Text(formatter.temperatureString(day.temperatureMin))
                .font(.subheadline)
                .opacity(0.85)
                .frame(width: 38, alignment: .trailing)
            TemperatureRangeBar(low: day.temperatureMin,
                                high: day.temperatureMax,
                                rangeMin: minTemp,
                                rangeMax: maxTemp)
                .frame(height: 6)
            Text(formatter.temperatureString(day.temperatureMax))
                .font(.subheadline.weight(.semibold))
                .frame(width: 38, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

struct TemperatureRangeBar: View {
    let low: Double
    let high: Double
    let rangeMin: Double
    let rangeMax: Double

    var body: some View {
        GeometryReader { geo in
            let span = max(0.001, rangeMax - rangeMin)
            let leftFrac = max(0.0, (low - rangeMin) / span)
            let rightFrac = min(1.0, (high - rangeMin) / span)
            let leftX = leftFrac * geo.size.width
            let rightX = rightFrac * geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(colors: [temperatureColor(celsius: low), temperatureColor(celsius: high)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8.0, rightX - leftX))
                    .offset(x: leftX)
            }
        }
    }
}
