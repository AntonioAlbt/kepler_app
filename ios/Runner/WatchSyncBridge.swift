// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2026 Jakob Krause
//
// This file is part of kepler_app. It is licensed under the GNU GPLv3.
// See the LICENSE file in the repository root for details.
//
// Senderseite: schickt die Plandaten aus der App-Group an die Apple Watch.
//
// Bewusst als FlutterPlugin registriert und nicht als Kanal auf dem rootViewController:
// workmanager_apple erzeugt fuer Hintergrund-Tasks eine EIGENE FlutterEngine. Ein von Hand
// registrierter Kanal existiert dort nicht, und genau aus dem Hintergrund heraus soll der
// Sync ja ausgeloest werden koennen.

import CryptoKit
import Flutter
import Foundation
import WatchConnectivity

public class WatchSyncBridge: NSObject, FlutterPlugin {
    private static let channelName = "kepler_app/watch_sync"
    // Kopien von appGroupId/dataKey/nextDataKey/planNamesKey: Massgeblich sind die Definitionen in
    // KeplerLockWidget.swift (die Datei gehoert nicht zum Runner-Target) bzw. iosWidgetAppGroupId
    // in lib/libs/plan_widgets.dart - bei Aenderungen alle Stellen anpassen.
    private static let appGroupId = "group.de.kepler-chemnitz.keplerapp"
    private static let dataKey = "data"
    private static let nextDataKey = "data_next"
    private static let planNamesKey = "plan_names"
    /// alles, was die Uhr braucht: beide Tagesplaene und die Plannamen fuer die Planauswahl
    private static let syncedKeys = [dataKey, nextDataKey, planNamesKey]
    /// zuletzt vergebene Revision (nur auf dem iPhone, siehe nextRevision)
    private static let revKey = "watch_sync_rev"
    /// Fingerabdruck des zuletzt uebertragenen Stands (nur auf dem iPhone, siehe fingerprint)
    private static let sentKey = "watch_sync_sent"

    private static let shared = WatchSyncBridge()

    /// sync() laeuft vom Flutter-Kanal (Main-Thread) und vom Session-Delegate (Hintergrund-Queue)
    /// aus - Revision und Fingerabdruck duerfen dabei nicht verzahnt gelesen und geschrieben werden
    private let lock = NSLock()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(shared, channel: channel)
        shared.activate()
    }

    // MARK: - Session

    private override init() { super.init() }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil { session.delegate = self }
        if session.activationState == .notActivated { session.activate() }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "syncNow":
            result(sync())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Uebertragung

    /// Liest den aktuellen Stand aus der App Group und schickt ihn an die Uhr.
    ///
    /// Kombiniert bewusst zwei Wege, weil sie unterschiedliche Luecken schliessen:
    /// - `updateApplicationContext`: "letzter Stand zaehlt". Ueberlebt eine ausgeschaltete Uhr und
    ///   liegt beim naechsten Aktivieren sofort bereit. Das ist das Sicherheitsnetz.
    /// - `transferCurrentComplicationUserInfo`: weckt die Uhr gezielt, um Complications zu
    ///   aktualisieren. Ohne diesen Weg wuerde der Kontext erst beim naechsten App-Start greifen.
    ///   Ist keine Complication aktiv, geht dieselbe Nutzlast per `transferUserInfo`.
    ///
    /// Unveraenderter Inhalt wird nicht erneut geschickt: Die App stoesst den Sync bei jeder
    /// Widget-Aktualisierung an, und jede Complication-Uebertragung kostet vom Tagesbudget
    /// (rund 50). `force` uebergeht das - fuer einen Wechsel der Uhr oder eine neu installierte
    /// Uhr-App, die den bisherigen Stand noch nicht hat.
    ///
    /// Es gibt bewusst KEINEN Guard auf `remainingComplicationUserInfoTransfers`: Ist das Budget
    /// erschoepft, degradiert der Aufruf laut SDK selbsttaetig zu regulaerem userInfo und stellt
    /// trotzdem zu - nur eben ohne Weckung. Ein eigener Guard wuerde die Zustellung ganz verhindern.
    ///
    /// Rueckgabe fuer Dart (watch_sync.dart): "ok" und bei `false` ein "reason". Ein
    /// uebersprungener, weil unveraenderter Stand gilt als Erfolg ("ok": true, "skipped").
    private func sync(force: Bool = false) -> [String: Any] {
        guard WCSession.isSupported() else {
            return ["ok": false, "reason": "unsupported"]
        }
        let session = WCSession.default
        activate()

        guard let defaults = UserDefaults(suiteName: Self.appGroupId) else {
            return ["ok": false, "reason": "no_app_group"]
        }

        lock.lock()
        defer { lock.unlock() }

        guard session.activationState == .activated else {
            return ["ok": false, "reason": "not_activated"]
        }
        guard session.isPaired else {
            return ["ok": false, "reason": "no_watch"]
        }
        guard session.isWatchAppInstalled else {
            // Wird die Uhr-App spaeter installiert, muss der naechste Sync auf jeden Fall senden -
            // auch wenn sich der Inhalt bis dahin nicht aendert.
            defaults.removeObject(forKey: Self.sentKey)
            return ["ok": false, "reason": "no_watch_app"]
        }

        var payload: [String: Any] = [:]
        for key in Self.syncedKeys {
            if let value = defaults.string(forKey: key) { payload[key] = value }
        }
        let fp = Self.fingerprint(payload, session: session)
        if !force && defaults.string(forKey: Self.sentKey) == fp {
            return ["ok": true, "skipped": "unchanged"]
        }

        let rev = Self.nextRevision(defaults)
        payload["rev"] = rev

        var ways: [String] = []
        var contextOk = true
        do {
            try session.updateApplicationContext(payload)
            ways.append("context")
        } catch {
            // Ein fehlgeschlagener Kontext darf den Complication-Transfer nicht verhindern
            ways.append("context_failed")
            contextOk = false
        }
        if session.isComplicationEnabled {
            session.transferCurrentComplicationUserInfo(payload)
            ways.append("complication")
        } else {
            session.transferUserInfo(payload)
            ways.append("userinfo")
        }

        // Nur als uebertragen merken, wenn auch das Sicherheitsnetz (Kontext) steht - sonst
        // versucht es der naechste Sync erneut.
        if contextOk {
            defaults.set(fp, forKey: Self.sentKey)
        } else {
            defaults.removeObject(forKey: Self.sentKey)
        }

        return ["ok": true, "rev": rev, "ways": ways,
                "remaining": session.remainingComplicationUserInfoTransfers]
    }

    /// Fingerabdruck des Inhalts (data, data_next, plan_names) fuer die gerade gekoppelte Uhr. Das
    /// Watch-Verzeichnis gehoert zur jeweiligen Kopplung - nach einem Wechsel der Uhr weicht der
    /// Fingerabdruck deshalb auch dann ab, wenn der Wechsel bei geschlossener App passiert ist.
    private static func fingerprint(_ payload: [String: Any], session: WCSession) -> String {
        var input = Data()
        for key in syncedKeys {
            // fehlender Wert und leerer String sollen sich unterscheiden
            if let value = payload[key] as? String {
                input.append(1)
                input.append(Data(value.utf8))
            }
            input.append(0)
        }
        input.append(Data((session.watchDirectoryURL?.path ?? "").utf8))
        return SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
    }

    /// Revision fuer die naechste Lieferung, damit die Uhr eine ueberholte Lieferung erkennt.
    ///
    /// Sekunden seit 1970 statt eines einfachen Zaehlers: Ein Zaehler finge nach einer Neuinstallation
    /// der iPhone-App wieder bei 1 an, und die Uhr (die sich die hoechste Revision merkt) wuerde
    /// danach alles verwerfen. Die Uhrzeit steigt dagegen auch ueber Neuinstallationen weiter.
    ///
    /// Mindestens letzte Revision + 1: Mehrere Lieferungen in derselben Sekunde und eine
    /// zurueckgestellte iPhone-Uhr ergeben so trotzdem steigende Werte. Springt die Uhrzeit
    /// dagegen weit vor und wieder zurueck, laufen die Revisionen eine Weile der Zeit voraus; die
    /// Uhr erkennt solche Werte und setzt ihren Stand zurueck (siehe WatchSync.apply).
    private static func nextRevision(_ defaults: UserDefaults) -> Int {
        let now = Int(Date().timeIntervalSince1970)
        let rev = max(now, defaults.integer(forKey: revKey) + 1)
        defaults.set(rev, forKey: revKey)
        return rev
    }
}

// MARK: - WCSessionDelegate (auf dem iPhone Pflicht, auch wenn nichts empfangen wird)

extension WatchSyncBridge: WCSessionDelegate {
    /// Ein Sync, der vor dem Ende der Aktivierung kam (z.B. Kaltstart im Hintergrund), wurde mit
    /// "not_activated" abgelehnt - hier nachholen. Unveraenderte Daten ueberspringt sync() ohnehin.
    public func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                        error: Error?) {
        if state == .activated { _ = sync() }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Beim Wechsel auf eine andere Uhr muss die Session neu aktiviert werden, sonst bleibt
    /// die Bruecke bis zum naechsten App-Start stumm.
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    /// Kopplung, Installation der Uhr-App oder Complication-Status haben sich geaendert (z.B.
    /// Uhr-App neu installiert) - dann den aktuellen Stand nachschicken, auch wenn er unveraendert ist.
    public func sessionWatchStateDidChange(_ session: WCSession) {
        _ = sync(force: true)
    }
}
