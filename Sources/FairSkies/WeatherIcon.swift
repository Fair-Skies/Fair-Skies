// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import FairSkiesModel

/// Renders a weather icon from the bundled symbolset assets, with an optional gentle animation.
public struct WeatherIcon: View {
    public let condition: WeatherCondition
    public let size: CGFloat
    public let animated: Bool

    public init(condition: WeatherCondition, size: CGFloat = 96, animated: Bool = true) {
        self.condition = condition
        self.size = size
        self.animated = animated
    }

    @State private var phase: Double = 0.0

    public var body: some View {
        Image(condition.iconName, bundle: .module)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(.white)
            .shadow(color: Color.black.opacity(0.25), radius: size * 0.05, x: 0, y: size * 0.04)
            .scaleEffect(animated ? (1.0 + 0.04 * sin(phase)) : 1.0)
            .rotationEffect(.degrees(animated ? (3.0 * sin(phase / 2.0)) : 0.0))
            .task {
                if animated {
                    withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                        phase = Double.pi * 2.0
                    }
                }
            }
    }
}

/// A small (icon-sized) weather glyph for use in lists and rows.
public struct WeatherGlyph: View {
    public let condition: WeatherCondition
    public let size: CGFloat
    public let tint: Color

    public init(condition: WeatherCondition, size: CGFloat = 24, tint: Color = .white) {
        self.condition = condition
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        Image(condition.iconName, bundle: .module)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
    }
}

/// A small icon from the asset catalog by name.
public struct AssetIcon: View {
    public let name: String
    public let size: CGFloat
    public let tint: Color

    public init(_ name: String, size: CGFloat = 22, tint: Color = .white) {
        self.name = name
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        Image(name, bundle: .module)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
    }
}
