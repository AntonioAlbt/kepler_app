// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2026 Jakob Krause
//
// This file is part of kepler_app. It is licensed under the GNU GPLv3.
// See the LICENSE file in the repository root for details.
//
// Empfaengerseite der Uhr: nimmt die Plandaten vom iPhone entgegen und legt sie in derselben
// App-Group-Struktur ab, die auch die iPhone-Widgets nutzen ("data"/"data_next" als JSON-String,
// "plan_names" als JSON-Liste). Dadurch lesen PlanStore und keplerPlanNames auf der Uhr voellig
// unveraendert - es gibt keine zweite Datenschicht.

import Foundation
import WatchConnectivity
import WidgetKit

/// Schreibt eingehende Plandaten in die App-Group der Uhr und laedt die Complications neu.
///
/// Bewusst ein starkes Singleton: WCSession haelt seinen Delegate nur schwach (`weak var delegate`).
/// Ein lokal erzeugtes Delegate wuerde sofort freigegeben und die Session bliebe stumm - ein Fehler,
/// der sich nur durch ausbleibende Daten aeussert, nicht durch einen Absturz.
final class WatchSync: NSObject, ObservableObject {
    static let shared = WatchSync()

    /// steigt bei jeder uebernommenen Aktualisierung - die Ansicht beobachtet das und rendert neu
    @Published private(set) var revision: Int = 0

    private let defaults = UserDefaults(suiteName: appGroupId)

    /// Revision der zuletzt uebernommenen Lieferung. Verhindert, dass eine aeltere Nachricht eine
    /// neuere ueberschreibt: `transferUserInfo` stellt zwar in Reihenfolge zu,
    /// `updateApplicationContext` aber unabhaengig davon - beide Wege koennen sich ueberholen.
    ///
    /// Das iPhone vergibt als Revision die Sekunden seit 1970 (siehe WatchSyncBridge.nextRevision).
    /// Als Int64 gelesen und gespeichert, weil Int auf aelteren Uhren (arm64_32) nur 32 Bit hat.
    private var lastRevision: Int64 {
        get { (defaults?.object(forKey: "sync_rev") as? NSNumber)?.int64Value ?? 0 }
        set { defaults?.set(NSNumber(value: newValue), forKey: "sync_rev") }
    }

    /// Spielraum fuer Uhrzeitabweichungen zwischen iPhone und Uhr
    private static let clockTolerance: Int64 = 24 * 60 * 60

    /// Obergrenze fuer das Warten in `waitForPendingContent`: Hintergrund-Aufgaben haben nur begrenzt
    /// Zeit, bevor watchOS die App wieder anhaelt.
    private static let pendingContentTimeout: TimeInterval = 10

    /// ob `activate()` die Aktivierung bereits angestossen hat (bis sie abgeschlossen ist, bleibt
    /// `activationState` noch `.notActivated`)
    private var activationRequested = false
    private let activationLock = NSLock()

    private override init() {
        super.init()
        activate()
    }

    /// Muss frueh im App-Start passieren, nicht erst beim Anzeigen einer Ansicht: nur eine
    /// aktivierte Session stellt Daten zu, wenn das iPhone die App im Hintergrund weckt.
    /// Mehrfaches Aufrufen ist unschaedlich (App-Delegate und `init` rufen es beide auf).
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        activationLock.lock()
        defer { activationLock.unlock() }
        guard !activationRequested, session.activationState != .activated else { return }
        activationRequested = true
        session.delegate = self
        session.activate()
    }

    /// Wartet, bis die Session aktiviert ist und nichts mehr zuzustellen hat (`hasContentPending`),
    /// hoechstens `pendingContentTimeout` Sekunden. Fuer `.backgroundTask(.watchConnectivity)`:
    /// erst danach darf die Hintergrund-Aufgabe enden.
    func waitForPendingContent() async {
        guard WCSession.isSupported() else { return }
        activate()
        let session = WCSession.default
        let deadline = Date().addingTimeInterval(Self.pendingContentTimeout)
        while !(session.activationState == .activated && !session.hasContentPending),
              Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        // apply() reicht das Neuladen der Complications per DispatchQueue.main.async weiter; die
        // Hauptwarteschlange arbeitet der Reihe nach ab, also ist danach auch das erledigt.
        await MainActor.run {}
    }

    /// Uebernimmt einen empfangenen Datensatz. Erwartet dieselbe Struktur, die das iPhone in die
    /// App Group schreibt: die Keys "data", "data_next" und "plan_names" mit dem JSON-String als Wert,
    /// dazu "rev" als monoton steigende Revision.
    ///
    /// Gibt zurueck, ob etwas uebernommen wurde - nur dann werden die Complications neu geladen.
    /// Das schont das ohnehin knappe Update-Budget der Uhr.
    @discardableResult
    func apply(_ payload: [String: Any]) -> Bool {
        guard let defaults else { return false }

        // Liegt die gespeicherte Revision weit in der Zukunft, stammt sie aus einer falsch gehenden
        // iPhone-Uhr (Revision = Sekunden seit 1970). Ohne Zuruecksetzen wuerde die Uhr bis zu
        // diesem Zeitpunkt jede Lieferung verwerfen.
        let now = Int64(Date().timeIntervalSince1970)
        if lastRevision > now + Self.clockTolerance { lastRevision = 0 }

        // ohne Revision unbrauchbar (die Bridge schickt immer eine), ueberholte Lieferung verwerfen
        guard let rev = (payload["rev"] as? NSNumber)?.int64Value, rev >= lastRevision else {
            return false
        }

        var changed = false
        for key in [dataKey, nextDataKey, planNamesKey] {
            let incoming = payload[key] as? String
            let current = defaults.string(forKey: key)
            guard incoming != current else { continue }
            if let incoming {
                defaults.set(incoming, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
            changed = true
        }
        lastRevision = rev

        guard changed else { return false }
        DispatchQueue.main.async {
            self.revision &+= 1
            WidgetCenter.shared.reloadAllTimelines()
        }
        return true
    }
}

// MARK: - WCSessionDelegate

extension WatchSync: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        // Beim Aktivieren liegt der zuletzt gesetzte Kontext bereits vor - auch wenn die Uhr
        // waehrend der Uebertragung aus war. Das ist der Selbstheilungspfad nach langer Trennung.
        guard state == .activated else {
            // fehlgeschlagen: der naechste activate()-Aufruf soll es erneut versuchen
            activationLock.lock()
            activationRequested = false
            activationLock.unlock()
            return
        }
        let context = session.receivedApplicationContext
        if !context.isEmpty { apply(context) }
    }

    /// "letzter Stand zaehlt" - der Grundzustand. Ueberschreibt aeltere Kontexte.
    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context)
    }

    /// Warteschlange - kommt auch an, wenn die Uhr zwischenzeitlich nicht erreichbar war.
    /// Hier kommen `transferCurrentComplicationUserInfo` und `transferUserInfo` des iPhones an.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        apply(userInfo)
    }
}
