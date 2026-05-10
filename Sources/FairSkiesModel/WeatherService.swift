// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// Errors that may be thrown by `WeatherService`.
public enum WeatherServiceError: Error, Equatable {
    case badResponse(status: Int)
    case noData
    case decoding(String)
}

/// Service that talks to the open-meteo.com weather and geocoding APIs.
///
/// All units returned by the service are in the API's native units (Celsius for temperature,
/// km/h for wind unless `windSpeedUnit` is set, mm for precipitation, hPa for pressure).
/// Unit conversion for display happens in `WeatherFormatter`.
public final class WeatherService: @unchecked Sendable {
    public static let shared = WeatherService()

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Look up locations matching the given query string using the Open-Meteo geocoding API.
    public func search(name: String, count: Int = 8, language: String = "en") async throws -> [GeocodingResult] {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let escaped = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let urlString = "https://geocoding-api.open-meteo.com/v1/search?name=\(escaped)&count=\(count)&language=\(language)&format=json"
        let url = URL(string: urlString)!
        let data = try await fetchData(url)
        let decoded = try Self.decoder.decode(GeocodingResponse.self, from: data)
        return decoded.results ?? []
    }

    /// Fetch a complete `WeatherReport` for the given location.
    public func fetchReport(for location: SavedLocation,
                            windSpeedUnit: WindSpeedUnit = .kmh,
                            forecastDays: Int = 7) async throws -> WeatherReport {
        let response = try await fetchOpenMeteoResponse(latitude: location.latitude,
                                                        longitude: location.longitude,
                                                        windSpeedUnit: windSpeedUnit,
                                                        forecastDays: forecastDays)
        return Self.makeReport(from: response, location: location)
    }

    /// Fetch the raw decoded API response. Useful for testing.
    public func fetchOpenMeteoResponse(latitude: Double,
                                       longitude: Double,
                                       windSpeedUnit: WindSpeedUnit = .kmh,
                                       forecastDays: Int = 7) async throws -> OpenMeteoResponse {
        let lat = Self.formatCoordinate(latitude)
        let lon = Self.formatCoordinate(longitude)
        let current = "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m,pressure_msl,cloud_cover,uv_index"
        let hourly = "temperature_2m,weather_code,precipitation_probability,wind_speed_10m,is_day"
        let daily = "temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset,uv_index_max,precipitation_sum,precipitation_probability_max,wind_speed_10m_max"
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=\(current)&hourly=\(hourly)&daily=\(daily)&timezone=auto&forecast_days=\(forecastDays)&wind_speed_unit=\(windSpeedUnit.apiParameter)"
        let url = URL(string: urlString)!
        let data = try await fetchData(url)
        return try Self.decoder.decode(OpenMeteoResponse.self, from: data)
    }

    /// Parses an `OpenMeteoResponse` payload into a `WeatherReport` keyed to the given location.
    public static func makeReport(from response: OpenMeteoResponse, location: SavedLocation) -> WeatherReport {
        let utcOffset: Double = response.utc_offset_seconds ?? 0.0
        let current = makeCurrent(block: response.current, utcOffset: utcOffset)
        let hourly = makeHourly(block: response.hourly, utcOffset: utcOffset)
        let daily = makeDaily(block: response.daily, utcOffset: utcOffset)
        return WeatherReport(location: location,
                             fetchedAt: Date(),
                             current: current,
                             hourly: hourly,
                             daily: daily)
    }

    private static func makeCurrent(block: OpenMeteoResponse.CurrentBlock?, utcOffset: Double) -> CurrentWeather {
        guard let c = block else {
            return CurrentWeather(temperature: 0.0, apparentTemperature: 0.0, relativeHumidity: 0.0,
                                  precipitation: 0.0, weatherCode: 0, isDay: true,
                                  windSpeed: 0.0, windDirection: 0.0, pressure: 1013.0,
                                  cloudCover: 0.0, uvIndex: 0.0, time: Date())
        }
        let temp = c.temperature_2m ?? 0.0
        let apparent = c.apparent_temperature ?? temp
        let humidity = c.relative_humidity_2m ?? 0.0
        let precip = c.precipitation ?? 0.0
        let code = c.weather_code ?? 0
        let dayFlag = c.is_day ?? 1
        let isDay = dayFlag > 0
        let windSpd = c.wind_speed_10m ?? 0.0
        let windDir = c.wind_direction_10m ?? 0.0
        let pressure = c.pressure_msl ?? 1013.0
        let cloud = c.cloud_cover ?? 0.0
        let uv = c.uv_index ?? 0.0
        let time = parseISODate(c.time, offset: utcOffset) ?? Date()
        return CurrentWeather(temperature: temp,
                              apparentTemperature: apparent,
                              relativeHumidity: humidity,
                              precipitation: precip,
                              weatherCode: code,
                              isDay: isDay,
                              windSpeed: windSpd,
                              windDirection: windDir,
                              pressure: pressure,
                              cloudCover: cloud,
                              uvIndex: uv,
                              time: time)
    }

    private static func makeHourly(block: OpenMeteoResponse.HourlyBlock?, utcOffset: Double) -> [HourlyForecast] {
        var result: [HourlyForecast] = []
        guard let h = block, let times = h.time else { return result }
        let temps: [Double] = h.temperature_2m ?? []
        let codes: [Int] = h.weather_code ?? []
        let probs: [Double] = h.precipitation_probability ?? []
        let winds: [Double] = h.wind_speed_10m ?? []
        let isDays: [Int] = h.is_day ?? []
        let count = times.count
        for i in 0..<count {
            let date = parseISODate(times[i], offset: utcOffset) ?? Date()
            let temp: Double = i < temps.count ? temps[i] : 0.0
            let code: Int = i < codes.count ? codes[i] : 0
            let prob: Double = i < probs.count ? probs[i] : 0.0
            let wind: Double = i < winds.count ? winds[i] : 0.0
            let dayFlag: Int = i < isDays.count ? isDays[i] : 1
            let isDay: Bool = dayFlag > 0
            result.append(HourlyForecast(time: date,
                                         temperature: temp,
                                         weatherCode: code,
                                         precipitationProbability: prob,
                                         windSpeed: wind,
                                         isDay: isDay))
        }
        return result
    }

    private static func makeDaily(block: OpenMeteoResponse.DailyBlock?, utcOffset: Double) -> [DailyForecast] {
        var result: [DailyForecast] = []
        guard let d = block, let times = d.time else { return result }
        let maxes: [Double] = d.temperature_2m_max ?? []
        let mins: [Double] = d.temperature_2m_min ?? []
        let codes: [Int] = d.weather_code ?? []
        let sunrises: [String] = d.sunrise ?? []
        let sunsets: [String] = d.sunset ?? []
        let uvs: [Double] = d.uv_index_max ?? []
        let precips: [Double] = d.precipitation_sum ?? []
        let probs: [Double] = d.precipitation_probability_max ?? []
        let winds: [Double] = d.wind_speed_10m_max ?? []
        let count = times.count
        for i in 0..<count {
            let date = parseISODate(times[i], offset: utcOffset) ?? Date()
            let high: Double = i < maxes.count ? maxes[i] : 0.0
            let low: Double = i < mins.count ? mins[i] : 0.0
            let code: Int = i < codes.count ? codes[i] : 0
            let sunrise: Date? = i < sunrises.count ? parseISODate(sunrises[i], offset: utcOffset) : nil
            let sunset: Date? = i < sunsets.count ? parseISODate(sunsets[i], offset: utcOffset) : nil
            let uv: Double = i < uvs.count ? uvs[i] : 0.0
            let precip: Double = i < precips.count ? precips[i] : 0.0
            let prob: Double = i < probs.count ? probs[i] : 0.0
            let wind: Double = i < winds.count ? winds[i] : 0.0
            result.append(DailyForecast(date: date,
                                        temperatureMax: high,
                                        temperatureMin: low,
                                        weatherCode: code,
                                        sunrise: sunrise,
                                        sunset: sunset,
                                        uvIndexMax: uv,
                                        precipitationSum: precip,
                                        precipitationProbabilityMax: prob,
                                        windSpeedMax: wind))
        }
        return result
    }

    private func fetchData(_ url: URL) async throws -> Data {
        logger.info("fetching: \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.setValue("FairSkies/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WeatherServiceError.badResponse(status: http.statusCode)
        }
        return data
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    /// Format a coordinate to 4 decimal places using a period as decimal separator.
    /// `String(format:)` honors the device locale on Android, which can produce
    /// "40,7128" on a comma-locale device — that breaks the Open-Meteo URL parser.
    /// We do an integer-based format manually to avoid the issue entirely.
    public static func formatCoordinate(_ value: Double) -> String {
        let negative = value < 0
        let absValue = negative ? -value : value
        let scaled = Int((absValue * 10000.0) + 0.5)
        let whole = scaled / 10000
        let frac = scaled - (whole * 10000)
        let fracString = leftPad(frac, width: 4)
        let signed = negative ? "-" : ""
        return "\(signed)\(whole).\(fracString)"
    }

    private static func leftPad(_ value: Int, width: Int) -> String {
        var s = "\(value)"
        while s.count < width {
            s = "0" + s
        }
        return s
    }

    /// Parse an ISO-style date string of the form `2024-05-09T13:00` (no timezone).
    /// The Open-Meteo API returns these times in the response's local `timezone`. To get a
    /// `Date` that represents the correct absolute instant, we offset the parsed UTC time
    /// by the response's `utc_offset_seconds` (subtracting it, since the parsed UTC
    /// instant is "ahead" of the local instant by that offset).
    public static func parseISODate(_ input: String?, offset: Double?) -> Date? {
        guard let input = input else { return nil }
        let off: Double = offset ?? 0.0
        let fmt = DateFormatter()
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let parsed = fmt.date(from: input) {
            return parsed.addingTimeInterval(-off)
        }
        // also handle date-only (sunrise/sunset for whole-day endpoints)
        fmt.dateFormat = "yyyy-MM-dd"
        if let parsed = fmt.date(from: input) {
            return parsed.addingTimeInterval(-off)
        }
        return nil
    }
}

// MARK: - Geocoding response

public struct GeocodingResponse: Codable, Hashable {
    public var results: [GeocodingResult]?
    public var generationtime_ms: Double?
}

public struct GeocodingResult: Codable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var elevation: Double?
    public var feature_code: String?
    public var country_code: String?
    public var country_id: Int?
    public var country: String?
    public var admin1: String?
    public var admin2: String?
    public var admin3: String?
    public var admin4: String?
    public var timezone: String?
    public var population: Int?

    public init(id: Int,
                name: String,
                latitude: Double,
                longitude: Double,
                elevation: Double? = nil,
                feature_code: String? = nil,
                country_code: String? = nil,
                country_id: Int? = nil,
                country: String? = nil,
                admin1: String? = nil,
                admin2: String? = nil,
                admin3: String? = nil,
                admin4: String? = nil,
                timezone: String? = nil,
                population: Int? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.feature_code = feature_code
        self.country_code = country_code
        self.country_id = country_id
        self.country = country
        self.admin1 = admin1
        self.admin2 = admin2
        self.admin3 = admin3
        self.admin4 = admin4
        self.timezone = timezone
        self.population = population
    }

    public var savedLocation: SavedLocation {
        SavedLocation(name: name,
                      admin: admin1,
                      country: country,
                      countryCode: country_code,
                      latitude: latitude,
                      longitude: longitude,
                      timezone: timezone)
    }
}

// MARK: - Forecast response

/// The raw JSON response shape returned by the Open-Meteo forecast API.
public struct OpenMeteoResponse: Codable, Hashable {
    public var latitude: Double?
    public var longitude: Double?
    public var generationtime_ms: Double?
    public var utc_offset_seconds: Double?
    public var timezone: String?
    public var timezone_abbreviation: String?
    public var elevation: Double?

    public var current: CurrentBlock?
    public var hourly: HourlyBlock?
    public var daily: DailyBlock?

    public struct CurrentBlock: Codable, Hashable {
        public var time: String?
        public var interval: Int?
        public var temperature_2m: Double?
        public var relative_humidity_2m: Double?
        public var apparent_temperature: Double?
        public var is_day: Int?
        public var precipitation: Double?
        public var weather_code: Int?
        public var wind_speed_10m: Double?
        public var wind_direction_10m: Double?
        public var pressure_msl: Double?
        public var cloud_cover: Double?
        public var uv_index: Double?
    }

    public struct HourlyBlock: Codable, Hashable {
        public var time: [String]?
        public var temperature_2m: [Double]?
        public var weather_code: [Int]?
        public var precipitation_probability: [Double]?
        public var wind_speed_10m: [Double]?
        public var is_day: [Int]?
    }

    public struct DailyBlock: Codable, Hashable {
        public var time: [String]?
        public var temperature_2m_max: [Double]?
        public var temperature_2m_min: [Double]?
        public var weather_code: [Int]?
        public var sunrise: [String]?
        public var sunset: [String]?
        public var uv_index_max: [Double]?
        public var precipitation_sum: [Double]?
        public var precipitation_probability_max: [Double]?
        public var wind_speed_10m_max: [Double]?
    }
}
