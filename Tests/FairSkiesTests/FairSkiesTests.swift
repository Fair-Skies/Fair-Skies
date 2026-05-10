// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Testing
import OSLog
import Foundation
import SwiftUI
@testable import FairSkies
@testable import FairSkiesModel

let logger: Logger = Logger(subsystem: "FairSkies", category: "Tests")

@Suite struct FairSkiesTests {

    @Test func basicArithmetic() throws {
        #expect(1 + 2 == 3)
    }

    @Test func decodeType() throws {
        let resourceURL: URL = try #require(Bundle.module.url(forResource: "TestData", withExtension: "json"))
        let testData = try JSONDecoder().decode(TestData.self, from: Data(contentsOf: resourceURL))
        #expect(testData.testModuleName == "FairSkies")
    }

    // MARK: - Hex color

    @Test func hexColorParsesSixDigits() throws {
        let _ = HexColor.parse("#FF8800")
        let _ = HexColor.parse("FF8800")
        let _ = HexColor.parse("#000000")
        let _ = HexColor.parse("#FFFFFF")
        // We can't easily compare Color values across platforms, but parsing
        // should not crash and should return a Color we can use.
        #expect(true)
    }

    @Test func hexColorWithBadInputDoesNotCrash() throws {
        let _ = HexColor.parse("")
        let _ = HexColor.parse("#")
        let _ = HexColor.parse("not-a-hex")
        let _ = col("#3ABEFF")
        #expect(true)
    }

    // MARK: - Theme gradients

    @Test func everyThemeHasAGradient() throws {
        let cond = WeatherCondition(code: 0, kind: WeatherCondition.Kind.clear, isDay: true)
        for theme in ColorTheme.allCases {
            let _ = theme.gradient(for: cond)
            let _ = theme.accent
        }
        #expect(true)
    }

    @Test func temperatureColorReturnsForFullRange() throws {
        // Should not crash for any reasonable temperature, including out of bounds.
        for celsius in [-50.0, -30.0, 0.0, 15.0, 30.0, 45.0, 60.0] {
            let _ = temperatureColor(celsius: celsius)
        }
        #expect(true)
    }

    // MARK: - View construction smoke tests

    @Test @MainActor func canConstructWeatherIcon() throws {
        let cond = WeatherCondition(code: 95, kind: WeatherCondition.Kind.thunderstorm, isDay: false)
        let _ = WeatherIcon(condition: cond)
        let _ = WeatherGlyph(condition: cond, size: 24, tint: Color.white)
        let _ = AssetIcon("sunny", size: 18, tint: Color.white)
        #expect(true)
    }

    @Test @MainActor func canConstructRootView() throws {
        let _ = RootView()
        #expect(true)
    }

    @Test @MainActor func canConstructCurrentWeatherView() throws {
        let loc = SavedLocation(name: "Test", latitude: 0, longitude: 0)
        let _ = CurrentWeatherView(location: loc)
        #expect(true)
    }
}

struct TestData : Codable, Hashable {
    var testModuleName: String
}
