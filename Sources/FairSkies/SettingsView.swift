// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import FairSkiesModel

/// User-facing settings: temperature unit, wind unit, color theme, animations,
/// 24-hour clock, and an About / Open-Meteo attribution section.
public struct SettingsView: View {
    @Environment(WeatherStore.self) var store: WeatherStore
    @Binding var showingSettings: Bool

    public init(showingSettings: Binding<Bool>) {
        self._showingSettings = showingSettings
    }

    public var body: some View {
        ZStack {
            ColorTheme.midnight.gradient(for: WeatherCondition(code: 0, kind: .clear, isDay: false))
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    unitsSection
                    appearanceSection
                    behaviorSection
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .foregroundStyle(.white)
        .navigationTitle("Settings")
        #if os(iOS) || SKIP
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    showingSettings = false
                }
                .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var unitsSection: some View {
        SettingsCard(title: "Units", icon: "thermometer") {
            VStack(spacing: 12) {
                SegmentedRow(title: "Temperature",
                             icon: "device_thermostat",
                             selection: tempBinding,
                             options: TemperatureUnit.allCases.map { ($0, $0.symbol) })
                SegmentedRow(title: "Wind Speed",
                             icon: "air",
                             selection: windBinding,
                             options: WindSpeedUnit.allCases.map { ($0, $0.label) })
            }
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        SettingsCard(title: "Appearance", icon: "palette") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Color Theme")
                    .font(.subheadline.weight(.medium))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(ColorTheme.allCases, id: \.self) { theme in
                        ThemeChip(theme: theme,
                                  isSelected: store.settings.theme == theme) {
                            store.updateSettings { $0.theme = theme }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var behaviorSection: some View {
        SettingsCard(title: "Behavior", icon: "settings") {
            VStack(spacing: 14) {
                ToggleRow(title: "Animated Icons",
                          icon: "cyclone",
                          isOn: animationsBinding)
                ToggleRow(title: "24-Hour Time",
                          icon: "schedule_default",
                          isOn: clockBinding)
                Button {
                    Task { await store.refreshAll() }
                } label: {
                    HStack(spacing: 8) {
                        AssetIcon("refresh", size: 18)
                        Text("Refresh All Locations")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        SettingsCard(title: "About", icon: "explore") {
            VStack(alignment: .leading, spacing: 8) {
                Text("FairSkies")
                    .font(.title3.weight(.semibold))
                Text("Beautiful weather for every sky.")
                    .font(.subheadline)
                    .opacity(0.85)
                Divider().background(Color.white.opacity(0.2))
                Text("Weather data is provided by Open-Meteo.com under the CC BY 4.0 license. The app is open source and licensed under GPL-2.0-or-later.")
                    .font(.caption)
                    .opacity(0.85)
            }
        }
    }

    // MARK: - Bindings

    private var tempBinding: Binding<TemperatureUnit> {
        Binding(get: { store.settings.temperatureUnit },
                set: { newValue in store.updateSettings { $0.temperatureUnit = newValue } })
    }

    private var windBinding: Binding<WindSpeedUnit> {
        Binding(get: { store.settings.windSpeedUnit },
                set: { newValue in store.updateSettings { $0.windSpeedUnit = newValue } })
    }

    private var animationsBinding: Binding<Bool> {
        Binding(get: { store.settings.showAnimations },
                set: { newValue in store.updateSettings { $0.showAnimations = newValue } })
    }

    private var clockBinding: Binding<Bool> {
        Binding(get: { store.settings.twentyFourHourTime },
                set: { newValue in store.updateSettings { $0.twentyFourHourTime = newValue } })
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                AssetIcon(icon, size: 16)
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
            }
            content()
        }
        .padding(14)
        .background(Color.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SegmentedRow<T: Hashable>: View {
    let title: String
    let icon: String
    @Binding var selection: T
    let options: [(T, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                AssetIcon(icon, size: 16)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            HStack(spacing: 6) {
                ForEach(Array(options.enumerated()), id: \.offset) { entry in
                    let opt = entry.element
                    Button {
                        selection = opt.0
                    } label: {
                        Text(opt.1)
                            .font(.caption.weight(.medium))
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(selection == opt.0 ? Color.white.opacity(0.30) : Color.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            AssetIcon(icon, size: 18)
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(col("#7CC4FF"))
        }
    }
}

struct ThemeChip: View {
    let theme: ColorTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let demoCondition = WeatherCondition(code: 0, kind: .clear, isDay: true)
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.gradient(for: demoCondition))
                        .frame(height: 56)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white, lineWidth: 2)
                            .frame(height: 56)
                        AssetIcon("star", size: 20)
                    }
                }
                Text(theme.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}
