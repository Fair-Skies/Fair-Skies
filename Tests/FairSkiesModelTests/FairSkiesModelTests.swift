// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Testing
import OSLog
import Foundation
@testable import FairSkiesModel

let logger: Logger = Logger(subsystem: "FairSkiesModel", category: "Tests")

@Suite struct FairSkiesModelTests {

    @Test func basicArithmetic() throws {
        #expect(1 + 2 == 3)
    }

    @Test func decodeType() throws {
        let resourceURL: URL = try #require(Bundle.module.url(forResource: "TestData", withExtension: "json"))
        let testData = try JSONDecoder().decode(TestData.self, from: Data(contentsOf: resourceURL))
        #expect(testData.testModuleName == "FairSkiesModel")
    }

    // MARK: - WeatherCondition mapping

    @Test func conditionFromCode_Clear() throws {
        let cond = WeatherCondition.from(code: 0, isDay: true)
        #expect(cond.kind == WeatherCondition.Kind.clear)
        #expect(cond.isDay == true)
        #expect(cond.iconName == "clear_day")
    }

    @Test func conditionFromCode_ClearNight() throws {
        let cond = WeatherCondition.from(code: 0, isDay: false)
        #expect(cond.kind == WeatherCondition.Kind.clear)
        #expect(cond.iconName == "clear_night")
    }

    @Test func conditionFromCode_PartlyCloudy() throws {
        let day = WeatherCondition.from(code: 1, isDay: true)
        #expect(day.kind == WeatherCondition.Kind.partlyCloudy)
        #expect(day.iconName == "partly_cloudy_day")

        let night = WeatherCondition.from(code: 2, isDay: false)
        #expect(night.kind == WeatherCondition.Kind.partlyCloudy)
        #expect(night.iconName == "partly_cloudy_night")
    }

    @Test func conditionFromCode_Overcast() throws {
        let cond = WeatherCondition.from(code: 3, isDay: true)
        #expect(cond.kind == WeatherCondition.Kind.overcast)
        #expect(cond.iconName == "cloudy")
    }

    @Test func conditionFromCode_Fog() throws {
        for code in [45, 48] {
            let cond = WeatherCondition.from(code: code, isDay: true)
            #expect(cond.kind == WeatherCondition.Kind.fog)
            #expect(cond.iconName == "foggy")
        }
    }

    @Test func conditionFromCode_Drizzle() throws {
        for code in [51, 53, 55, 56, 57] {
            let cond = WeatherCondition.from(code: code, isDay: true)
            #expect(cond.kind == WeatherCondition.Kind.drizzle, "code \(code)")
        }
    }

    @Test func conditionFromCode_Rain() throws {
        for code in [61, 63, 65] {
            let cond = WeatherCondition.from(code: code, isDay: true)
            #expect(cond.kind == WeatherCondition.Kind.rain, "code \(code)")
        }
    }

    @Test func conditionFromCode_FreezingRain() throws {
        for code in [66, 67] {
            let cond = WeatherCondition.from(code: code, isDay: true)
            #expect(cond.kind == WeatherCondition.Kind.freezingRain, "code \(code)")
        }
    }

    @Test func conditionFromCode_Snow() throws {
        for code in [71, 73, 75] {
            let cond = WeatherCondition.from(code: code, isDay: true)
            #expect(cond.kind == WeatherCondition.Kind.snow, "code \(code)")
        }
        let grain = WeatherCondition.from(code: 77, isDay: true)
        #expect(grain.kind == WeatherCondition.Kind.snowGrain)
    }

    @Test func conditionFromCode_Showers() throws {
        for code in [80, 81, 82] {
            let cond = WeatherCondition.from(code: code, isDay: true)
            #expect(cond.kind == WeatherCondition.Kind.rainShowers, "code \(code)")
        }
        for code in [85, 86] {
            let cond = WeatherCondition.from(code: code, isDay: true)
            #expect(cond.kind == WeatherCondition.Kind.snowShowers, "code \(code)")
        }
    }

    @Test func conditionFromCode_Thunderstorm() throws {
        let normal = WeatherCondition.from(code: 95, isDay: true)
        #expect(normal.kind == WeatherCondition.Kind.thunderstorm)
        for code in [96, 99] {
            let hail = WeatherCondition.from(code: code, isDay: true)
            #expect(hail.kind == WeatherCondition.Kind.thunderstormHail, "code \(code)")
        }
    }

    @Test func conditionFromCode_Unknown() throws {
        let cond = WeatherCondition.from(code: 1234, isDay: true)
        #expect(cond.kind == WeatherCondition.Kind.unknown)
    }

    @Test func conditionGradientHexAlwaysStartsWithHash() throws {
        for code in [0, 1, 2, 3, 45, 51, 61, 71, 80, 95, 99] {
            let dayCond = WeatherCondition.from(code: code, isDay: true)
            #expect(dayCond.gradientHex.top.hasPrefix("#"))
            #expect(dayCond.gradientHex.bottom.hasPrefix("#"))
            let nightCond = WeatherCondition.from(code: code, isDay: false)
            #expect(nightCond.gradientHex.top.hasPrefix("#"))
            #expect(nightCond.gradientHex.bottom.hasPrefix("#"))
        }
    }

    @Test func conditionLabelNotEmpty() throws {
        for kind in WeatherCondition.Kind.allCases {
            let cond = WeatherCondition(code: 0, kind: kind, isDay: true)
            #expect(!cond.label.isEmpty, "kind \(kind)")
            #expect(!cond.iconName.isEmpty, "kind \(kind)")
        }
    }

    // MARK: - WeatherFormatter

    @Test func temperatureConversionCelsius() throws {
        let f = WeatherFormatter(temperatureUnit: TemperatureUnit.celsius)
        #expect(f.convertTemperature(0.0) == 0.0)
        #expect(f.convertTemperature(20.0) == 20.0)
        #expect(f.convertTemperature(-10.0) == -10.0)
    }

    @Test func temperatureConversionFahrenheit() throws {
        let f = WeatherFormatter(temperatureUnit: TemperatureUnit.fahrenheit)
        #expect(f.convertTemperature(0.0) == 32.0)
        #expect(f.convertTemperature(100.0) == 212.0)
        // 20C = 68F
        #expect(f.convertTemperature(20.0) == 68.0)
    }

    @Test func temperatureStringRoundsToInt() throws {
        let f = WeatherFormatter(temperatureUnit: TemperatureUnit.celsius)
        #expect(f.temperatureString(20.4) == "20\u{00B0}")
        #expect(f.temperatureString(20.6) == "21\u{00B0}")
        #expect(f.temperatureString(-3.4) == "-3\u{00B0}")
        #expect(f.temperatureString(-3.6) == "-4\u{00B0}")
    }

    @Test func temperatureStringWithUnit() throws {
        let c = WeatherFormatter(temperatureUnit: TemperatureUnit.celsius)
        #expect(c.temperatureString(20.0, withUnit: true) == "20\u{00B0}C")
        let fa = WeatherFormatter(temperatureUnit: TemperatureUnit.fahrenheit)
        #expect(fa.temperatureString(0.0, withUnit: true) == "32\u{00B0}F")
    }

    @Test func windSpeedConversion() throws {
        let kmh = WeatherFormatter(windSpeedUnit: WindSpeedUnit.kmh)
        #expect(kmh.windSpeedString(36.0) == "36 km/h")
        let mph = WeatherFormatter(windSpeedUnit: WindSpeedUnit.mph)
        // 36 km/h = ~22.4 mph -> rounds to 22
        #expect(mph.windSpeedString(36.0) == "22 mph")
        let ms = WeatherFormatter(windSpeedUnit: WindSpeedUnit.ms)
        // 36 km/h = 10 m/s
        #expect(ms.windSpeedString(36.0) == "10 m/s")
        let kn = WeatherFormatter(windSpeedUnit: WindSpeedUnit.knots)
        // 36 km/h = ~19.4 knots -> 19
        #expect(kn.windSpeedString(36.0) == "19 kn")
    }

    @Test func windDirectionString() throws {
        let f = WeatherFormatter()
        #expect(f.windDirectionString(0.0) == "N")
        #expect(f.windDirectionString(90.0) == "E")
        #expect(f.windDirectionString(180.0) == "S")
        #expect(f.windDirectionString(270.0) == "W")
        #expect(f.windDirectionString(45.0) == "NE")
        #expect(f.windDirectionString(225.0) == "SW")
        #expect(f.windDirectionString(360.0) == "N")
        // negative degrees should normalize
        #expect(f.windDirectionString(-90.0) == "W")
    }

    @Test func humidityString() throws {
        let f = WeatherFormatter()
        #expect(f.humidityString(0.0) == "0%")
        #expect(f.humidityString(62.4) == "62%")
        #expect(f.humidityString(99.6) == "100%")
    }

    @Test func uvCategoryThresholds() throws {
        let f = WeatherFormatter()
        #expect(f.uvCategory(0.0) == "Low")
        #expect(f.uvCategory(2.9) == "Low")
        #expect(f.uvCategory(3.0) == "Moderate")
        #expect(f.uvCategory(5.9) == "Moderate")
        #expect(f.uvCategory(6.0) == "High")
        #expect(f.uvCategory(7.9) == "High")
        #expect(f.uvCategory(8.0) == "Very High")
        #expect(f.uvCategory(11.0) == "Extreme")
    }

    @Test func pressureString() throws {
        let f = WeatherFormatter()
        #expect(f.pressureString(1013.4) == "1013 hPa")
        #expect(f.pressureString(1024.9) == "1025 hPa")
    }

    // MARK: - Open-Meteo response decoding

    @Test func decodeForecastResponse() throws {
        let url = try #require(Bundle.module.url(forResource: "SampleForecast", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        #expect(decoded.latitude == 52.52)
        #expect(decoded.longitude == 13.41)
        #expect(decoded.timezone == "GMT")
        #expect(decoded.current?.temperature_2m == 18.4)
        #expect(decoded.current?.weather_code == 2)
        #expect(decoded.current?.is_day == 1)
        #expect(decoded.hourly?.time?.count == 4)
        #expect(decoded.daily?.temperature_2m_max?.count == 3)
    }

    @Test func makeReportFromResponse() throws {
        let url = try #require(Bundle.module.url(forResource: "SampleForecast", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        let location = SavedLocation(name: "Berlin", latitude: 52.52, longitude: 13.41, timezone: "GMT")
        let report = WeatherService.makeReport(from: decoded, location: location)

        // Current
        #expect(report.current.temperature == 18.4)
        #expect(report.current.weatherCode == 2)
        #expect(report.current.isDay == true)
        #expect(report.current.condition.kind == WeatherCondition.Kind.partlyCloudy)
        #expect(report.current.condition.isDay == true)
        #expect(report.current.relativeHumidity == 62.0)
        #expect(report.current.pressure == 1013.4)

        // Hourly
        #expect(report.hourly.count == 4)
        #expect(report.hourly[0].temperature == 18.4)
        #expect(report.hourly[3].weatherCode == 80)
        #expect(report.hourly[3].condition.kind == WeatherCondition.Kind.rainShowers)

        // Daily
        #expect(report.daily.count == 3)
        #expect(report.daily[0].temperatureMax == 21.5)
        #expect(report.daily[0].temperatureMin == 11.2)
        #expect(report.daily[1].weatherCode == 61)
        #expect(report.daily[1].precipitationSum == 5.4)
        #expect(report.daily[2].sunrise != nil)
        #expect(report.daily[2].sunset != nil)
    }

    @Test func decodeGeocodingResponse() throws {
        let url = try #require(Bundle.module.url(forResource: "SampleGeocoding", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        let results = try #require(decoded.results)
        #expect(results.count == 2)
        let berlinDE = results[0]
        #expect(berlinDE.name == "Berlin")
        #expect(berlinDE.country == "Germany")
        #expect(berlinDE.country_code == "DE")
        #expect(berlinDE.population == 3426354)
        #expect(berlinDE.timezone == "Europe/Berlin")

        let saved = berlinDE.savedLocation
        #expect(saved.name == "Berlin")
        #expect(saved.country == "Germany")
        #expect(saved.timezone == "Europe/Berlin")
    }

    @Test func parseISODateBasic() throws {
        let parsed = WeatherService.parseISODate("2026-05-09T12:00", offset: 0.0)
        #expect(parsed != nil)
        // Date should round-trip when formatting the same way
        if let parsed = parsed {
            let fmt = DateFormatter()
            fmt.timeZone = TimeZone(identifier: "UTC")
            fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
            #expect(fmt.string(from: parsed) == "2026-05-09T12:00")
        }
    }

    @Test func parseISODateWithOffset() throws {
        // With a +3600 offset (UTC+1), local 12:00 corresponds to UTC 11:00
        let parsed = try #require(WeatherService.parseISODate("2026-05-09T12:00", offset: 3600.0))
        let fmt = DateFormatter()
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        #expect(fmt.string(from: parsed) == "2026-05-09T11:00")
    }

    @Test func parseISODateInvalid() throws {
        let parsed = WeatherService.parseISODate("not-a-date", offset: 0.0)
        #expect(parsed == nil)
    }

    @Test func parseISODateNil() throws {
        let parsed = WeatherService.parseISODate(nil, offset: 0.0)
        #expect(parsed == nil)
    }

    @Test func formatCoordinateUsesPeriodDecimal() throws {
        // Critical: must always use '.' as decimal separator regardless of device
        // locale (Android comma-locales would otherwise produce malformed URLs).
        #expect(WeatherService.formatCoordinate(40.7128) == "40.7128")
        #expect(WeatherService.formatCoordinate(-74.006) == "-74.0060")
        #expect(WeatherService.formatCoordinate(0.0) == "0.0000")
        #expect(WeatherService.formatCoordinate(51.5074) == "51.5074")
        #expect(WeatherService.formatCoordinate(-33.8688) == "-33.8688")
    }

    // MARK: - WeatherStore

    @Test func storeSeedsDefaultsWhenEmpty() throws {
        let store = makeIsolatedStore()
        #expect(!store.locations.isEmpty)
        #expect(store.selectedLocationID != nil)
    }

    @Test func storeAddRemoveLocations() throws {
        let store = makeIsolatedStore()
        let initialCount = store.locations.count
        let testLoc = SavedLocation(name: "TestVille", latitude: 1.0, longitude: 2.0)
        store.add(testLoc)
        #expect(store.locations.count == initialCount + 1)
        // adding same coords should be a no-op
        store.add(SavedLocation(name: "TestVille2", latitude: 1.0, longitude: 2.0))
        #expect(store.locations.count == initialCount + 1)
        store.remove(testLoc)
        #expect(store.locations.count == initialCount)
    }

    @Test func storeRemoveAtIndices() throws {
        let store = makeIsolatedStore()
        let initialCount = store.locations.count
        if initialCount >= 2 {
            store.remove(at: [0, 1])
            #expect(store.locations.count == initialCount - 2)
        }
    }

    @Test func storeMoveLocations() throws {
        let store = makeIsolatedStore()
        guard store.locations.count >= 3 else { return }
        let firstID = store.locations[0].id
        // Move from position 0 to position 2.
        // For [A, B, C, ...] -> remove A -> [B, C, ...] -> insert at 2 -> [B, C, A, ...]
        store.move(from: 0, to: 2)
        #expect(store.locations[2].id == firstID)
    }

    @Test func storeUpdateSettings() throws {
        let store = makeIsolatedStore()
        store.updateSettings { $0.temperatureUnit = TemperatureUnit.fahrenheit }
        #expect(store.settings.temperatureUnit == TemperatureUnit.fahrenheit)
        store.updateSettings { $0.theme = ColorTheme.sunset }
        #expect(store.settings.theme == ColorTheme.sunset)
    }

    @Test func storePersistsAndReloads() throws {
        let dir = try uniqueTempDir()
        let url = dir.appendingPathComponent("state.json")
        let store1 = WeatherStore(stateURL: url, seedDefaults: false)
        let loc = SavedLocation(name: "PersistVille", latitude: 1.0, longitude: 2.0)
        store1.add(loc)
        store1.updateSettings { $0.temperatureUnit = TemperatureUnit.fahrenheit }

        // create a fresh store at the same URL
        let store2 = WeatherStore(stateURL: url, seedDefaults: false)
        #expect(store2.locations.count == 1)
        #expect(store2.locations[0].name == "PersistVille")
        #expect(store2.settings.temperatureUnit == TemperatureUnit.fahrenheit)
    }

    @Test func loadStateIsLoading() throws {
        #expect(LoadState.loading.isLoading == true)
        #expect(LoadState.idle.isLoading == false)
        #expect(LoadState.loaded(Date()).isLoading == false)
        #expect(LoadState.failed("err").isLoading == false)
    }

    @Test func savedLocationDisplaySubtitle() throws {
        let loc = SavedLocation(name: "Boston", admin: "Massachusetts", country: "United States",
                                latitude: 42.36, longitude: -71.05)
        #expect(loc.displaySubtitle == "Massachusetts, United States")

        let bare = SavedLocation(name: "Atlantis", latitude: 0, longitude: 0)
        #expect(bare.displaySubtitle == "")
    }

    @Test func defaultLocationsHaveNonEmptyNames() throws {
        for loc in WeatherStore.defaultLocations {
            #expect(!loc.name.isEmpty)
            #expect(loc.timezone != nil)
        }
    }

    // MARK: - Helpers

    private func makeIsolatedStore() -> WeatherStore {
        let url = isolatedStateURL()
        return WeatherStore(stateURL: url, seedDefaults: true)
    }

    private func isolatedStateURL() -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("FairSkiesTests-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        } catch {
            // ignore - tests still run from a path that may not exist; persist will retry
        }
        return base.appendingPathComponent("state.json")
    }

    private func uniqueTempDir() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("FairSkiesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
}

struct TestData : Codable, Hashable {
    var testModuleName: String
}
