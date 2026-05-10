// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import FairSkiesModel

/// Top-level view: a paged carousel of saved locations, with a sliding settings
/// sheet and a "manage locations" sheet for adding/removing locations.
public struct RootView: View {
    @State private var store = WeatherStore()
    @State private var showingLocations = false
    @State private var showingSettings = false
    @State private var pageIndex: Int = 0

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            content
            controlBar
        }
        .preferredColorScheme(preferredScheme)
        .environment(store)
        .sheet(isPresented: $showingLocations) {
            NavigationStack {
                LocationsView(showingLocations: $showingLocations)
                    .environment(store)
                    .preferredColorScheme(preferredScheme)
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView(showingSettings: $showingSettings)
                    .environment(store)
                    .preferredColorScheme(preferredScheme)
            }
        }
        .task {
            await store.refreshAll()
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.locations.isEmpty {
            emptyState
        } else {
            #if os(iOS) || os(Android)
            TabView(selection: $pageIndex) {
                ForEach(Array(store.locations.enumerated()), id: \.offset) { entry in
                    CurrentWeatherView(location: entry.element)
                        .tag(entry.offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            #else
            // On macOS, fall back to a stack with manual paging buttons.
            VStack(spacing: 0) {
                if pageIndex < store.locations.count {
                    CurrentWeatherView(location: store.locations[pageIndex])
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        ZStack {
            ColorTheme.midnight.gradient(for: WeatherCondition(code: 0, kind: .clear, isDay: false))
                .ignoresSafeArea()
            VStack(spacing: 20) {
                AssetIcon("explore", size: 84)
                Text("Welcome to FairSkies")
                    .font(.title2.weight(.semibold))
                Text("Add a location to begin tracking weather")
                    .font(.subheadline)
                    .opacity(0.85)
                Button {
                    showingLocations = true
                } label: {
                    Label("Add Location", systemImage: "plus.circle.fill")
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                showingLocations = true
            } label: {
                AssetIcon("location_on", size: 22, tint: .white)
                    .padding(10)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            pagerDots
            Spacer()
            Button {
                showingSettings = true
            } label: {
                AssetIcon("settings", size: 22, tint: .white)
                    .padding(10)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .opacity(store.locations.isEmpty ? 0.0 : 1.0)
    }

    @ViewBuilder
    private var pagerDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(store.locations.enumerated()), id: \.offset) { entry in
                Circle()
                    .fill(entry.offset == pageIndex ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 8.0, height: 8.0)
            }
        }
    }

    private var preferredScheme: ColorScheme? {
        switch store.settings.theme {
        case .automatic: return nil
        case .ocean, .sunset, .forest, .rose: return .dark
        case .midnight, .mono: return .dark
        }
    }
}
