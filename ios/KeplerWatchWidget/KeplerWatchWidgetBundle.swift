// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2026 Jakob Krause
//
// This file is part of kepler_app. It is licensed under the GNU GPLv3.
// See the LICENSE file in the repository root for details.
//
// Complications fuer die Apple Watch. Sie nutzen dieselben Widget-Typen wie die
// iPhone-Sperrbildschirm-Widgets (KeplerLockWidget.swift) - auf watchOS greift dort die
// StaticConfiguration mit WatchProvider, weil die Uhr immer den primaer ausgewaehlten Plan zeigt.

import WidgetKit
import SwiftUI

@main
struct KeplerWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        KeplerLockWidget()      // aktuelle Stunde
        KeplerNextLockWidget()  // naechste Stunde
    }
}
