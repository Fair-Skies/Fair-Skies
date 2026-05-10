// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Observation

/// The status of a single location's weather fetch.
public enum LoadState: Hashable {
    case idle
    case loading
    case loaded(Date)
    case failed(String)

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

/// The top-level observable state for the app: saved locations, current report per location,
/// load states, and persisted user settings.
///
/// The store persists locations and settings to disk under
/// `Application Support/fair-skies/state.json`. Reports are kept in memory only (cached
/// per-location key), and re-fetched on launch.
@Observable public final class WeatherStore {
    /// Persisted, ordered list of saved locations. The first location is the "primary" one.
    public var locations: [SavedLocation]
    /// User preferences for units, theme, etc.
    public var settings: WeatherSettings
    /// The most recently fetched report keyed by location id.
    public var reports: [UUID: WeatherReport]
    /// The fetch state keyed by location id.
    public var loadStates: [UUID: LoadState]
    /// The id of the location currently selected in the UI, if any.
    public var selectedLocationID: UUID?

    /// Service used for fetching weather data. Replaceable for tests.
    @ObservationIgnored public var service: WeatherService

    /// File URL used to persist `locations` and `settings`.
    @ObservationIgnored public var stateURL: URL

    public init(service: WeatherService = WeatherService.shared,
                stateURL: URL? = nil,
                seedDefaults: Bool = true) {
        self.service = service
        self.stateURL = stateURL ?? Self.defaultStateURL()
        let loaded = Self.loadState(from: self.stateURL)
        if let loaded = loaded {
            self.locations = loaded.locations
            self.settings = loaded.settings
        } else if seedDefaults {
            self.locations = Self.defaultLocations
            self.settings = WeatherSettings.default
        } else {
            self.locations = []
            self.settings = WeatherSettings.default
        }
        self.reports = [:]
        self.loadStates = [:]
        self.selectedLocationID = self.locations.first?.id
    }

    public var selectedLocation: SavedLocation? {
        guard let id = selectedLocationID else { return locations.first }
        return locations.first(where: { $0.id == id }) ?? locations.first
    }

    public var formatter: WeatherFormatter {
        WeatherFormatter(temperatureUnit: settings.temperatureUnit,
                         windSpeedUnit: settings.windSpeedUnit,
                         twentyFourHourTime: settings.twentyFourHourTime)
    }

    public func report(for location: SavedLocation) -> WeatherReport? {
        return reports[location.id]
    }

    public func loadState(for location: SavedLocation) -> LoadState {
        return loadStates[location.id] ?? .idle
    }

    @MainActor
    public func refresh(_ location: SavedLocation) async {
        loadStates[location.id] = .loading
        do {
            let report = try await service.fetchReport(for: location, windSpeedUnit: settings.windSpeedUnit)
            reports[location.id] = report
            loadStates[location.id] = .loaded(Date())
        } catch {
            loadStates[location.id] = .failed("\(error)")
            logger.error("failed to fetch weather for \(location.name): \(error)")
        }
    }

    @MainActor
    public func refreshAll() async {
        for location in locations {
            await refresh(location)
        }
    }

    public func add(_ location: SavedLocation) {
        guard !locations.contains(where: { $0.latitude == location.latitude && $0.longitude == location.longitude }) else {
            return
        }
        locations.append(location)
        if selectedLocationID == nil {
            selectedLocationID = location.id
        }
        persist()
    }

    public func remove(at indices: [Int]) {
        let sorted = indices.sorted(by: >)
        var removedIds: [UUID] = []
        for idx in sorted {
            if idx >= 0 && idx < locations.count {
                removedIds.append(locations[idx].id)
                locations.remove(at: idx)
            }
        }
        for id in removedIds {
            reports.removeValue(forKey: id)
            loadStates.removeValue(forKey: id)
        }
        if let sel = selectedLocationID, !locations.contains(where: { $0.id == sel }) {
            selectedLocationID = locations.first?.id
        }
        persist()
    }

    public func remove(_ location: SavedLocation) {
        locations.removeAll(where: { $0.id == location.id })
        reports.removeValue(forKey: location.id)
        loadStates.removeValue(forKey: location.id)
        if selectedLocationID == location.id {
            selectedLocationID = locations.first?.id
        }
        persist()
    }

    public func move(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < locations.count else { return }
        let item = locations.remove(at: sourceIndex)
        let dest = max(0, min(destinationIndex, locations.count))
        locations.insert(item, at: dest)
        persist()
    }

    public func updateSettings(_ update: (inout WeatherSettings) -> Void) {
        var copy = settings
        update(&copy)
        settings = copy
        persist()
    }

    /// Persist `locations` and `settings` to disk.
    public func persist() {
        let snapshot = PersistedState(locations: locations, settings: settings)
        do {
            let data = try JSONEncoder().encode(snapshot)
            let dir = stateURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: stateURL)
        } catch {
            logger.error("failed to persist state: \(error)")
        }
    }

    /// Resolve to URL `Application Support/fair-skies/state.json`.
    public static func defaultStateURL() -> URL {
        let dir = URL.applicationSupportDirectory.appendingPathComponent("fair-skies", isDirectory: true)
        return dir.appendingPathComponent("state.json")
    }

    private static func loadState(from url: URL) -> PersistedState? {
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(PersistedState.self, from: data)
            return decoded
        } catch {
            return nil
        }
    }

    /// A small set of default locations seeded for first launch.
    public static let defaultLocations: [SavedLocation] = [
        SavedLocation(name: "San Francisco", admin: "California", country: "United States", countryCode: "US",
                      latitude: 37.7749, longitude: -122.4194, timezone: "America/Los_Angeles"),
        SavedLocation(name: "New York", admin: "New York", country: "United States", countryCode: "US",
                      latitude: 40.7128, longitude: -74.0060, timezone: "America/New_York"),
        SavedLocation(name: "London", admin: "England", country: "United Kingdom", countryCode: "GB",
                      latitude: 51.5074, longitude: -0.1278, timezone: "Europe/London"),
        SavedLocation(name: "Tokyo", admin: "Tokyo", country: "Japan", countryCode: "JP",
                      latitude: 35.6895, longitude: 139.6917, timezone: "Asia/Tokyo"),
        SavedLocation(name: "Sydney", admin: "New South Wales", country: "Australia", countryCode: "AU",
                      latitude: -33.8688, longitude: 151.2093, timezone: "Australia/Sydney"),
    ]
}

/// On-disk envelope for saved state.
public struct PersistedState: Codable, Hashable {
    public var locations: [SavedLocation]
    public var settings: WeatherSettings

    public init(locations: [SavedLocation], settings: WeatherSettings) {
        self.locations = locations
        self.settings = settings
    }
}
