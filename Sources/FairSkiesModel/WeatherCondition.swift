// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// A normalized weather condition derived from a WMO weather code.
///
/// The WMO weather interpretation codes used by Open-Meteo are documented at
/// https://open-meteo.com/en/docs and follow these groupings:
///
///   0:        Clear sky
///   1, 2, 3:  Mainly clear, partly cloudy, overcast
///   45, 48:   Fog and depositing rime fog
///   51..57:   Drizzle and freezing drizzle (light/moderate/dense)
///   61..67:   Rain and freezing rain (slight/moderate/heavy)
///   71..77:   Snow fall, snow grains
///   80..82:   Rain showers (slight/moderate/violent)
///   85..86:   Snow showers (slight/heavy)
///   95:       Thunderstorm (slight/moderate)
///   96, 99:   Thunderstorm with hail
public struct WeatherCondition: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Hashable, CaseIterable, Sendable {
        case clear
        case partlyCloudy
        case cloudy
        case overcast
        case fog
        case drizzle
        case rain
        case freezingRain
        case snow
        case snowGrain
        case rainShowers
        case snowShowers
        case thunderstorm
        case thunderstormHail
        case unknown
    }

    public var code: Int
    public var kind: Kind
    public var isDay: Bool

    public init(code: Int, kind: Kind, isDay: Bool) {
        self.code = code
        self.kind = kind
        self.isDay = isDay
    }

    /// The localized short label for the condition.
    public var label: String {
        switch kind {
        case .clear: return isDay ? "Clear" : "Clear Night"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy: return "Mostly Cloudy"
        case .overcast: return "Overcast"
        case .fog: return "Fog"
        case .drizzle: return "Drizzle"
        case .rain: return "Rain"
        case .freezingRain: return "Freezing Rain"
        case .snow: return "Snow"
        case .snowGrain: return "Snow Grains"
        case .rainShowers: return "Rain Showers"
        case .snowShowers: return "Snow Showers"
        case .thunderstorm: return "Thunderstorm"
        case .thunderstormHail: return "Thunderstorm with Hail"
        case .unknown: return "Unknown"
        }
    }

    /// The asset name (in `Module.xcassets`) of the icon best representing this condition.
    public var iconName: String {
        switch kind {
        case .clear: return isDay ? "clear_day" : "clear_night"
        case .partlyCloudy: return isDay ? "partly_cloudy_day" : "partly_cloudy_night"
        case .cloudy: return "cloud"
        case .overcast: return "cloudy"
        case .fog: return "foggy"
        case .drizzle: return "rainy"
        case .rain: return "rainy"
        case .freezingRain: return "weather_mix"
        case .snow: return "snowing"
        case .snowGrain: return "weather_snowy"
        case .rainShowers: return "rainy"
        case .snowShowers: return "weather_snowy"
        case .thunderstorm: return "thunderstorm"
        case .thunderstormHail: return "weather_hail"
        case .unknown: return "cloud"
        }
    }

    /// A pair of hex color strings (top, bottom) suitable for a gradient background for this condition.
    public var gradientHex: (top: String, bottom: String) {
        switch kind {
        case .clear:
            return isDay ? ("#4FB3FF", "#0A6CB6") : ("#0F1A3F", "#0B1024")
        case .partlyCloudy:
            return isDay ? ("#7CB7E5", "#446A8A") : ("#1F2845", "#0E1124")
        case .cloudy:
            return isDay ? ("#9CB4C4", "#586E7E") : ("#3A4250", "#1A1F28")
        case .overcast:
            return isDay ? ("#7C8C99", "#48555F") : ("#2E3540", "#13171E")
        case .fog:
            return isDay ? ("#BFC8CE", "#7E878D") : ("#3F454C", "#1B1F24")
        case .drizzle:
            return isDay ? ("#6989B0", "#3A547A") : ("#1F2A47", "#0F1426")
        case .rain:
            return isDay ? ("#4F7AA0", "#1F3F60") : ("#1A2742", "#0A0F1F")
        case .freezingRain:
            return isDay ? ("#7AAAC8", "#3F6585") : ("#22344A", "#0E1626")
        case .snow:
            return isDay ? ("#D8E5F0", "#7E9AB0") : ("#2C3950", "#10172A")
        case .snowGrain:
            return isDay ? ("#CDDCE8", "#7E94A8") : ("#2A3548", "#0F1626")
        case .rainShowers:
            return isDay ? ("#5878A0", "#2A4868") : ("#1B2840", "#0A1020")
        case .snowShowers:
            return isDay ? ("#B8CDDC", "#6A819A") : ("#28344A", "#0E1626")
        case .thunderstorm:
            return isDay ? ("#3D4C6E", "#1A1F36") : ("#15192C", "#06080F")
        case .thunderstormHail:
            return isDay ? ("#3F4C66", "#1B2238") : ("#181C2E", "#070912")
        case .unknown:
            return ("#6E7B89", "#2E3942")
        }
    }

    /// Returns a `WeatherCondition` corresponding to the given WMO code and day/night flag.
    public static func from(code: Int, isDay: Bool) -> WeatherCondition {
        let kind = mapKind(code)
        return WeatherCondition(code: code, kind: kind, isDay: isDay)
    }

    private static func mapKind(_ code: Int) -> Kind {
        switch code {
        case 0: return .clear
        case 1, 2: return .partlyCloudy
        case 3: return .overcast
        case 45, 48: return .fog
        case 51, 53, 55, 56, 57: return .drizzle
        case 61, 63, 65: return .rain
        case 66, 67: return .freezingRain
        case 71, 73, 75: return .snow
        case 77: return .snowGrain
        case 80, 81, 82: return .rainShowers
        case 85, 86: return .snowShowers
        case 95: return .thunderstorm
        case 96, 99: return .thunderstormHail
        default: return .unknown
        }
    }
}
