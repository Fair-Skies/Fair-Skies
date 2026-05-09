// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Testing
import OSLog
import Foundation
@testable import FairSkies

let logger: Logger = Logger(subsystem: "FairSkies", category: "Tests")

@Suite struct FairSkiesTests {

    @Test func fairSkies() throws {
        logger.log("running testFairSkies")
        #expect(1 + 2 == 3, "basic test")
    }

    @Test func decodeType() throws {
        // load the TestData.json file from the Resources folder and decode it into a struct
        let resourceURL: URL = try #require(Bundle.module.url(forResource: "TestData", withExtension: "json"))
        let testData = try JSONDecoder().decode(TestData.self, from: Data(contentsOf: resourceURL))
        #expect(testData.testModuleName == "FairSkies")
    }

}

struct TestData : Codable, Hashable {
    var testModuleName: String
}
