// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import FairSkiesModel

/// Helpers for converting weather model values into SwiftUI presentation primitives
/// (colors, gradients, icons).
extension WeatherCondition {
    /// The pair of colors (top, bottom) for this condition's atmospheric gradient.
    public var gradientColors: (top: Color, bottom: Color) {
        let pair = gradientHex
        return (col(pair.top), col(pair.bottom))
    }

    /// The full gradient backdrop for this condition.
    public var gradient: LinearGradient {
        let pair = gradientColors
        return LinearGradient(colors: [pair.top, pair.bottom], startPoint: .top, endPoint: .bottom)
    }
}

extension ColorTheme {
    /// Compute a gradient pair for a theme; for `.automatic`, fall back to the condition's own gradient.
    public func gradient(for condition: WeatherCondition) -> LinearGradient {
        switch self {
        case .automatic:
            return condition.gradient
        case .ocean:
            return LinearGradient(colors: [col("#3ABEFF"), col("#0D4F8B")], startPoint: .top, endPoint: .bottom)
        case .sunset:
            return LinearGradient(colors: [col("#FF8C42"), col("#A02B6E")], startPoint: .top, endPoint: .bottom)
        case .forest:
            return LinearGradient(colors: [col("#5DA56C"), col("#1F3F30")], startPoint: .top, endPoint: .bottom)
        case .midnight:
            return LinearGradient(colors: [col("#1B2747"), col("#070914")], startPoint: .top, endPoint: .bottom)
        case .rose:
            return LinearGradient(colors: [col("#FF7BAA"), col("#80224F")], startPoint: .top, endPoint: .bottom)
        case .mono:
            return LinearGradient(colors: [col("#7A8087"), col("#1E2024")], startPoint: .top, endPoint: .bottom)
        }
    }

    /// Accent color for buttons and chips when this theme is active.
    public var accent: Color {
        switch self {
        case .automatic: return Color.white
        case .ocean: return col("#A4E5FF")
        case .sunset: return col("#FFD7A8")
        case .forest: return col("#C5E8C9")
        case .midnight: return col("#A8B5DD")
        case .rose: return col("#FFD2E2")
        case .mono: return col("#E0E2E5")
        }
    }
}

/// Convert a temperature in Celsius to a color from cool blue (cold) to warm orange/red (hot).
/// Output color is independent of the user's display unit.
public func temperatureColor(celsius: Double) -> Color {
    let clamped = max(-30.0, min(45.0, celsius))
    // Map -30..45 -> 0..1
    let p = (clamped + 30.0) / 75.0
    // Stops: deep blue -> cyan -> green -> yellow -> orange -> red.
    // Stored as flat parallel arrays rather than tuple-of-tuples since Skip
    // doesn't transpile nested tuple element access (`stops[i].1.0`).
    let positions: [Double] = [0.0, 0.25, 0.45, 0.65, 0.85, 1.0]
    let reds: [Double] = [0.20, 0.30, 0.55, 0.95, 0.95, 0.90]
    let greens: [Double] = [0.40, 0.85, 0.85, 0.85, 0.55, 0.25]
    let blues: [Double] = [0.95, 0.95, 0.45, 0.35, 0.30, 0.25]
    let count = positions.count
    for i in 0..<(count - 1) {
        let lo = positions[i]
        let hi = positions[i + 1]
        if p >= lo && p <= hi {
            let span = hi - lo
            let t: Double = span > 0 ? (p - lo) / span : 0.0
            let r = reds[i] + (reds[i + 1] - reds[i]) * t
            let g = greens[i] + (greens[i + 1] - greens[i]) * t
            let b = blues[i] + (blues[i + 1] - blues[i]) * t
            return Color(red: r, green: g, blue: b)
        }
    }
    return Color.white
}

/// Helpers for constructing a `Color` from a hex string like "#RRGGBB".
/// (Defined as namespaced statics rather than an `init` extension since Skip cannot
/// add constructors to types defined outside the current module.)
public enum HexColor {
    public static func parse(_ hex: String) -> Color {
        // Strip any leading '#' without using `removeFirst` on String (Skip stdlib
        // does not implement that mutator).
        let trimmed: String
        if hex.hasPrefix("#") {
            trimmed = String(hex.dropFirst())
        } else {
            trimmed = hex
        }
        // Manual hex parsing — substring + character lookup. We avoid Scanner
        // (not in Skip Foundation), .unicodeScalars (transpilation issues with
        // generic .map type inference), and any 64-bit arithmetic so transpiled
        // Kotlin stays within 32-bit range.
        var r: Int = 0
        var g: Int = 0
        var b: Int = 0
        if trimmed.count >= 6 {
            r = (hexDigit(charAt(trimmed, 0)) * 16) + hexDigit(charAt(trimmed, 1))
            g = (hexDigit(charAt(trimmed, 2)) * 16) + hexDigit(charAt(trimmed, 3))
            b = (hexDigit(charAt(trimmed, 4)) * 16) + hexDigit(charAt(trimmed, 5))
        }
        return Color(red: Double(r) / 255.0,
                     green: Double(g) / 255.0,
                     blue: Double(b) / 255.0)
    }

    private static func charAt(_ s: String, _ index: Int) -> String {
        let i = s.index(s.startIndex, offsetBy: index)
        return String(s[i])
    }

    private static func hexDigit(_ ch: String) -> Int {
        switch ch {
        case "0": return 0
        case "1": return 1
        case "2": return 2
        case "3": return 3
        case "4": return 4
        case "5": return 5
        case "6": return 6
        case "7": return 7
        case "8": return 8
        case "9": return 9
        case "a", "A": return 10
        case "b", "B": return 11
        case "c", "C": return 12
        case "d", "D": return 13
        case "e", "E": return 14
        case "f", "F": return 15
        default: return 0
        }
    }
}

/// Convenience alias used throughout the UI to build colors from hex strings.
public func col(_ hex: String) -> Color {
    HexColor.parse(hex)
}
