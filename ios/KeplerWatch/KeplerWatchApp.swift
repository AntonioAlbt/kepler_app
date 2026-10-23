// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2026 Jakob Krause
//
// This file is part of kepler_app. It is licensed under the GNU GPLv3.
// See the LICENSE file in the repository root for details.
//
// Einstiegspunkt der Apple-Watch-App. Sie hat genau einen Bildschirm: den Tagesplan.
// Die Daten kommen vom iPhone (siehe WatchSync) und liegen in derselben App-Group-Struktur
// wie auf dem iPhone, damit PlanStore unveraendert genutzt werden kann.

import SwiftUI
import WatchKit

@main
struct KeplerWatchApp: App {
    /// aktiviert die Session schon beim Start - auch beim Wecken im Hintergrund, wenn noch keine
    /// Ansicht (und damit kein `sync` unten) erzeugt wurde
    @WKApplicationDelegateAdaptor private var appDelegate: WatchAppDelegate

    /// Der Sync muss den gesamten App-Lebenszyklus ueberdauern: WCSession haelt seinen Delegate
    /// nur schwach. Ein lokal erzeugtes Objekt waere sofort wieder weg und die Session stumm.
    @StateObject private var sync = WatchSync.shared

    var body: some Scene {
        WindowGroup {
            DayPlanScreen()
                .environmentObject(sync)
        }
        // watchOS weckt die App im Hintergrund, wenn das iPhone Daten schickt
        // (transferCurrentComplicationUserInfo, updateApplicationContext). Endet die Aufgabe, bevor
        // die Session alles zugestellt hat, wird die App wieder angehalten und die Lieferung bleibt
        // liegen - deshalb warten, bis nichts mehr aussteht.
        .backgroundTask(.watchConnectivity) {
            await WatchSync.shared.waitForPendingContent()
        }
    }
}

/// Einstieg fuer den App-Start (auch im Hintergrund): aktiviert die WCSession so frueh wie moeglich.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchSync.shared.activate()
    }
}
