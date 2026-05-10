// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// Formatter for converting weather values in API native units to user-facing strings.
public struct WeatherFormatter {
    public let temperatureUnit: TemperatureUnit
    public let windSpeedUnit: WindSpeedUnit
    public let twentyFourHourTime: Bool

    public init(temperatureUnit: TemperatureUnit = .celsius,
                windSpeedUnit: WindSpeedUnit = .kmh,
                twentyFourHourTime: Bool = false) {
        self.temperatureUnit = temperatureUnit
        self.windSpeedUnit = windSpeedUnit
        self.twentyFourHourTime = twentyFourHourTime
    }

    /// Converts a Celsius value to the configured display unit.
    public func convertTemperature(_ celsius: Double) -> Double {
        switch temperatureUnit {
        case .celsius: return celsius
        case .fahrenheit: return (celsius * 9.0 / 5.0) + 32.0
        }
    }

    /// Returns a temperature display value with degree symbol e.g. "23°".
    public func temperatureString(_ celsius: Double, withUnit: Bool = false) -> String {
        let converted = convertTemperature(celsius)
        let rounded = (converted >= 0 ? Int(converted + 0.5) : -Int(-converted + 0.5))
        if withUnit {
            return "\(rounded)\(temperatureUnit.symbol)"
        } else {
            return "\(rounded)\u{00B0}"
        }
    }

    /// Returns a precise temperature with one decimal place e.g. "23.4°C".
    public func preciseTemperatureString(_ celsius: Double) -> String {
        let converted = convertTemperature(celsius)
        let rounded = roundTo(converted, places: 1)
        return "\(rounded)\(temperatureUnit.symbol)"
    }

    /// Returns a wind-speed display string in the configured unit, with the unit suffix.
    public func windSpeedString(_ kmh: Double) -> String {
        let value: Double
        switch windSpeedUnit {
        case .kmh: value = kmh
        case .mph: value = kmh * 0.621371
        case .ms: value = kmh / 3.6
        case .knots: value = kmh * 0.539957
        }
        let rounded = Int(value + 0.5)
        return "\(rounded) \(windSpeedUnit.label)"
    }

    /// A 16-direction compass abbreviation for the given degrees from north.
    public func windDirectionString(_ degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        // Compute degrees mod 360 manually to avoid Foundation's truncatingRemainder,
        // which is not implemented in Skip's Kotlin stdlib.
        let whole = floor(degrees / 360.0)
        var d = degrees - (whole * 360.0)
        if d < 0 { d += 360.0 }
        let idx = Int((d / 22.5) + 0.5) % 16
        return directions[idx]
    }

    /// Returns a 0-100% display string e.g. "62%".
    public func humidityString(_ value: Double) -> String {
        let rounded = Int(value + 0.5)
        return "\(rounded)%"
    }

    /// Returns a precipitation amount in millimeters with one decimal place.
    public func precipitationString(_ mm: Double) -> String {
        let rounded = roundTo(mm, places: 1)
        return "\(rounded) mm"
    }

    /// Returns a pressure display string in hPa.
    public func pressureString(_ hpa: Double) -> String {
        let rounded = Int(hpa + 0.5)
        return "\(rounded) hPa"
    }

    /// Returns a UV index display string with category label.
    public func uvIndexString(_ value: Double) -> String {
        let rounded = Int(value + 0.5)
        return "\(rounded) (\(uvCategory(value)))"
    }

    public func uvCategory(_ value: Double) -> String {
        if value < 3 { return "Low" }
        if value < 6 { return "Moderate" }
        if value < 8 { return "High" }
        if value < 11 { return "Very High" }
        return "Extreme"
    }

    /// Returns a short hour label e.g. "3 PM" or "15".
    public func hourString(_ date: Date, timezoneIdentifier: String? = nil) -> String {
        let fmt = DateFormatter()
        if let tz = timezoneIdentifier, let zone = TimeZone(identifier: tz) {
            fmt.timeZone = zone
        }
        fmt.dateFormat = twentyFourHourTime ? "HH" : "h a"
        return fmt.string(from: date)
    }

    /// Returns a short weekday label like "Mon".
    public func weekdayString(_ date: Date, timezoneIdentifier: String? = nil) -> String {
        let fmt = DateFormatter()
        if let tz = timezoneIdentifier, let zone = TimeZone(identifier: tz) {
            fmt.timeZone = zone
        }
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }

    /// Returns a clock string like "5:43 AM" or "05:43".
    public func clockString(_ date: Date, timezoneIdentifier: String? = nil) -> String {
        let fmt = DateFormatter()
        if let tz = timezoneIdentifier, let zone = TimeZone(identifier: tz) {
            fmt.timeZone = zone
        }
        fmt.dateFormat = twentyFourHourTime ? "HH:mm" : "h:mm a"
        return fmt.string(from: date)
    }

    /// Whether the given date is the same calendar day as today (in the given timezone).
    public func isToday(_ date: Date, timezoneIdentifier: String? = nil) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        if let tz = timezoneIdentifier, let zone = TimeZone(identifier: tz) {
            calendar.timeZone = zone
        }
        return calendar.isDateInToday(date)
    }

    /// Round a Double to a given number of fractional digits using a base-10 scale.
    /// Note: scales are kept small (10^places) to avoid 32-bit overflow on Kotlin/Android.
    fileprivate func roundTo(_ value: Double, places: Int) -> Double {
        var multiplier = 1.0
        for _ in 0..<places {
            multiplier *= 10.0
        }
        let rounded = (value * multiplier).rounded() / multiplier
        return rounded
    }
}
