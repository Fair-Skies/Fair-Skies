// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import OSLog
import SwiftUI

/// A logger for the FairSkies module.
let logger: Logger = Logger(subsystem: "org.appfair.app.Fair-Skies", category: "FairSkies")

/// The shared top-level view for the app, loaded from the platform-specific App delegates below.
public struct FairSkiesRootView : View {
    public init() {
    }

    public var body: some View {
        RootView()
            .task {
                logger.info("FairSkies launching - logs viewable in Xcode console (iOS) or adb logcat (Android)")
            }
    }
}

/// Global application delegate functions.
///
/// These functions can update a shared observable object to communicate app state changes to interested views.
public final class FairSkiesAppDelegate : Sendable {
    public static let shared = FairSkiesAppDelegate()

    private init() {
    }

    public func onInit() {
        logger.debug("onInit")
    }

    public func onLaunch() {
        logger.debug("onLaunch")
    }

    public func onResume() {
        logger.debug("onResume")
    }

    public func onPause() {
        logger.debug("onPause")
    }

    public func onStop() {
        logger.debug("onStop")
    }

    public func onDestroy() {
        logger.debug("onDestroy")
    }

    public func onLowMemory() {
        logger.debug("onLowMemory")
    }
}
