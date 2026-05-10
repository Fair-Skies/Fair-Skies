// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import OSLog

/// A logger for the FairSkiesModel module.
public let logger: Logger = Logger(subsystem: "fair.skies.model", category: "FairSkiesModel")

/// Temperature display unit.
public enum TemperatureUnit: String, Codable, CaseIterable, Hashable, Sendable {
    case celsius
    case fahrenheit

    public var symbol: String {
        switch self {
        case .celsius: return "\u{00B0}C"
        case .fahrenheit: return "\u{00B0}F"
        }
    }
}

/// Wind speed display unit.
public enum WindSpeedUnit: String, Codable, CaseIterable, Hashable, Sendable {
    case kmh
    case mph
    case ms
    case knots

    public var label: String {
        switch self {
        case .kmh: return "km/h"
        case .mph: return "mph"
        case .ms: return "m/s"
        case .knots: return "kn"
        }
    }

    /// Open-Meteo API parameter value for wind_speed_unit.
    public var apiParameter: String {
        switch self {
        case .kmh: return "kmh"
        case .mph: return "mph"
        case .ms: return "ms"
        case .knots: return "kn"
        }
    }
}

/// Color theme for the app.
public enum ColorTheme: String, Codable, CaseIterable, Hashable, Sendable {
    case automatic
    case ocean
    case sunset
    case forest
    case midnight
    case rose
    case mono

    public var label: String {
        switch self {
        case .automatic: return "Dynamic"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        case .midnight: return "Midnight"
        case .rose: return "Rose"
        case .mono: return "Mono"
        }
    }
}

/// A single saved location with the weather snapshot we last fetched.
public struct SavedLocation: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var admin: String?
    public var country: String?
    public var countryCode: String?
    public var latitude: Double
    public var longitude: Double
    public var timezone: String?
    public var isCurrent: Bool

    public init(id: UUID = UUID(),
                name: String,
                admin: String? = nil,
                country: String? = nil,
                countryCode: String? = nil,
                latitude: Double,
                longitude: Double,
                timezone: String? = nil,
                isCurrent: Bool = false) {
        self.id = id
        self.name = name
        self.admin = admin
        self.country = country
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
        self.isCurrent = isCurrent
    }

    public var displaySubtitle: String {
        var parts: [String] = []
        if let admin = admin, !admin.isEmpty {
            parts.append(admin)
        }
        if let country = country, !country.isEmpty {
            parts.append(country)
        }
        return parts.joined(separator: ", ")
    }
}

/// A complete weather report for a single location, combining current conditions, hourly and daily forecast.
public struct WeatherReport: Hashable, Codable {
    public var location: SavedLocation
    public var fetchedAt: Date
    public var current: CurrentWeather
    public var hourly: [HourlyForecast]
    public var daily: [DailyForecast]

    public init(location: SavedLocation,
                fetchedAt: Date,
                current: CurrentWeather,
                hourly: [HourlyForecast],
                daily: [DailyForecast]) {
        self.location = location
        self.fetchedAt = fetchedAt
        self.current = current
        self.hourly = hourly
        self.daily = daily
    }
}

/// Current weather conditions, in API native units (Celsius temperature, km/h wind, etc.).
public struct CurrentWeather: Hashable, Codable {
    public var temperature: Double
    public var apparentTemperature: Double
    public var relativeHumidity: Double
    public var precipitation: Double
    public var weatherCode: Int
    public var isDay: Bool
    public var windSpeed: Double
    public var windDirection: Double
    public var pressure: Double
    public var cloudCover: Double
    public var uvIndex: Double
    public var time: Date

    public init(temperature: Double,
                apparentTemperature: Double,
                relativeHumidity: Double,
                precipitation: Double,
                weatherCode: Int,
                isDay: Bool,
                windSpeed: Double,
                windDirection: Double,
                pressure: Double,
                cloudCover: Double,
                uvIndex: Double,
                time: Date) {
        self.temperature = temperature
        self.apparentTemperature = apparentTemperature
        self.relativeHumidity = relativeHumidity
        self.precipitation = precipitation
        self.weatherCode = weatherCode
        self.isDay = isDay
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.pressure = pressure
        self.cloudCover = cloudCover
        self.uvIndex = uvIndex
        self.time = time
    }

    public var condition: WeatherCondition {
        WeatherCondition.from(code: weatherCode, isDay: isDay)
    }
}

/// A single hourly forecast entry.
public struct HourlyForecast: Hashable, Codable, Identifiable {
    public var id: Date { time }
    public var time: Date
    public var temperature: Double
    public var weatherCode: Int
    public var precipitationProbability: Double
    public var windSpeed: Double
    public var isDay: Bool

    public init(time: Date,
                temperature: Double,
                weatherCode: Int,
                precipitationProbability: Double,
                windSpeed: Double,
                isDay: Bool) {
        self.time = time
        self.temperature = temperature
        self.weatherCode = weatherCode
        self.precipitationProbability = precipitationProbability
        self.windSpeed = windSpeed
        self.isDay = isDay
    }

    public var condition: WeatherCondition {
        WeatherCondition.from(code: weatherCode, isDay: isDay)
    }
}

/// A single daily forecast entry.
public struct DailyForecast: Hashable, Codable, Identifiable {
    public var id: Date { date }
    public var date: Date
    public var temperatureMax: Double
    public var temperatureMin: Double
    public var weatherCode: Int
    public var sunrise: Date?
    public var sunset: Date?
    public var uvIndexMax: Double
    public var precipitationSum: Double
    public var precipitationProbabilityMax: Double
    public var windSpeedMax: Double

    public init(date: Date,
                temperatureMax: Double,
                temperatureMin: Double,
                weatherCode: Int,
                sunrise: Date?,
                sunset: Date?,
                uvIndexMax: Double,
                precipitationSum: Double,
                precipitationProbabilityMax: Double,
                windSpeedMax: Double) {
        self.date = date
        self.temperatureMax = temperatureMax
        self.temperatureMin = temperatureMin
        self.weatherCode = weatherCode
        self.sunrise = sunrise
        self.sunset = sunset
        self.uvIndexMax = uvIndexMax
        self.precipitationSum = precipitationSum
        self.precipitationProbabilityMax = precipitationProbabilityMax
        self.windSpeedMax = windSpeedMax
    }

    public var condition: WeatherCondition {
        WeatherCondition.from(code: weatherCode, isDay: true)
    }
}

/// User-facing weather settings persisted across launches.
public struct WeatherSettings: Hashable, Codable, Sendable {
    public var temperatureUnit: TemperatureUnit
    public var windSpeedUnit: WindSpeedUnit
    public var theme: ColorTheme
    public var showAnimations: Bool
    public var twentyFourHourTime: Bool

    public init(temperatureUnit: TemperatureUnit = .celsius,
                windSpeedUnit: WindSpeedUnit = .kmh,
                theme: ColorTheme = .automatic,
                showAnimations: Bool = true,
                twentyFourHourTime: Bool = false) {
        self.temperatureUnit = temperatureUnit
        self.windSpeedUnit = windSpeedUnit
        self.theme = theme
        self.showAnimations = showAnimations
        self.twentyFourHourTime = twentyFourHourTime
    }

    public static let `default` = WeatherSettings()
}
