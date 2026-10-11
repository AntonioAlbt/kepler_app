// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2026 Jakob Krause
//
// This file is part of kepler_app. It is licensed under the GNU GPLv3.
// See the LICENSE file in the repository root for details.

import WidgetKit
import SwiftUI

@main
struct KeplerLockWidgetBundle: WidgetBundle {
    var body: some Widget {
        KeplerLockWidget()      // Sperrbildschirm: aktuelle Stunde
        KeplerNextLockWidget()  // Sperrbildschirm: nächste Stunde
        KeplerCurrentWidget()   // Homescreen: aktuelle Stunde
        KeplerNextWidget()      // Homescreen: nächste Stunde
        KeplerDayWidget()       // Homescreen: Tagesplan
    }
}
