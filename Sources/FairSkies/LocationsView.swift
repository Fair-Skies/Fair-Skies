// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import FairSkiesModel

/// Displays the saved locations with a search bar to add new locations from the
/// Open-Meteo geocoding API. Saved locations show a small thumbnail of their
/// current weather; tapping a result row adds it to the saved list.
public struct LocationsView: View {
    @Environment(WeatherStore.self) var store: WeatherStore
    @Binding var showingLocations: Bool
    @State private var searchText: String = ""
    @State private var searchResults: [GeocodingResult] = []
    @State private var isSearching = false
    @State private var searchError: String? = nil
    @State private var lastSearched: String = ""

    public init(showingLocations: Binding<Bool>) {
        self._showingLocations = showingLocations
    }

    public var body: some View {
        ZStack {
            ColorTheme.midnight.gradient(for: WeatherCondition(code: 0, kind: .clear, isDay: false))
                .ignoresSafeArea()
            VStack(spacing: 0) {
                searchField
                listSection
            }
        }
        .foregroundStyle(.white)
        .navigationTitle("Locations")
        #if os(iOS) || SKIP
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    showingLocations = false
                }
                .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var searchField: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                AssetIcon("search", size: 18)
                TextField("Search city or postal code", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await runSearch() }
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        searchError = nil
                    } label: {
                        AssetIcon("delete_outline", size: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.18))
            .clipShape(Capsule())
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var listSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !searchText.isEmpty {
                    searchResultsList
                }
                savedLocationsList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Search Results".uppercased())
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
                Spacer()
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
            }
            if let err = searchError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(col("#FFB0B0"))
            }
            if !isSearching && searchResults.isEmpty && !lastSearched.isEmpty && searchError == nil {
                Text("No locations found.")
                    .font(.caption)
                    .opacity(0.85)
            }
            ForEach(searchResults) { result in
                Button {
                    addResult(result)
                } label: {
                    HStack(spacing: 12) {
                        AssetIcon("add", size: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.white)
                            Text(subtitle(for: result))
                                .font(.caption)
                                .opacity(0.85)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var savedLocationsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Saved Locations".uppercased())
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
                Spacer()
            }
            if store.locations.isEmpty {
                Text("No saved locations yet.")
                    .font(.caption)
                    .opacity(0.85)
            }
            ForEach(store.locations) { saved in
                LocationRow(location: saved,
                            report: store.report(for: saved),
                            formatter: store.formatter)
                    .background(Color.white.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .trailing) {
                        Button {
                            store.remove(saved)
                        } label: {
                            AssetIcon("delete_outline", size: 22, tint: col("#FFC7C7"))
                                .padding(10)
                        }
                        .buttonStyle(.plain)
                    }
            }
        }
    }

    private func subtitle(for r: GeocodingResult) -> String {
        var parts: [String] = []
        if let admin1 = r.admin1, !admin1.isEmpty {
            parts.append(admin1)
        }
        if let country = r.country, !country.isEmpty {
            parts.append(country)
        }
        return parts.joined(separator: ", ")
    }

    private func addResult(_ r: GeocodingResult) {
        let saved = r.savedLocation
        store.add(saved)
        // Trigger an immediate refresh so the new card has data on the home screen.
        Task { await store.refresh(saved) }
        // Clear the search bar so the user sees their saved locations.
        searchText = ""
        searchResults = []
        lastSearched = ""
    }

    private func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        searchError = nil
        lastSearched = query
        do {
            let results = try await store.service.search(name: query, count: 10)
            searchResults = results
        } catch {
            searchError = "Search failed: \(error)"
            searchResults = []
        }
        isSearching = false
    }
}

struct LocationRow: View {
    let location: SavedLocation
    let report: WeatherReport?
    let formatter: WeatherFormatter

    var body: some View {
        HStack(spacing: 12) {
            if let report = report {
                WeatherGlyph(condition: report.current.condition, size: 30, tint: .white)
            } else {
                AssetIcon("location_on", size: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.body.weight(.semibold))
                Text(location.displaySubtitle)
                    .font(.caption)
                    .opacity(0.85)
            }
            Spacer()
            if let report = report {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatter.temperatureString(report.current.temperature))
                        .font(.title3.weight(.semibold))
                    if let today = report.daily.first {
                        HStack(spacing: 4) {
                            Text("\u{2191}\(formatter.temperatureString(today.temperatureMax))")
                            Text("\u{2193}\(formatter.temperatureString(today.temperatureMin))")
                        }
                        .font(.caption)
                        .opacity(0.85)
                    }
                }
                .padding(.trailing, 36)
            }
        }
        .padding(12)
    }
}
