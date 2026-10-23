// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2026 Jakob Krause
//
// This file is part of kepler_app. It is licensed under the GNU GPLv3.
// See the LICENSE file in the repository root for details.
//
// Sperrbildschirm-Widgets (iOS) bzw. Complications (watchOS), die Fach, Raum und Lehrer der
// aktuellen bzw. nächsten Stunde aus dem ausgewählten (Vertretungs-)Plan anzeigen. Die Daten werden
// von der Flutter-App über das home_widget-Plugin in die App-Group geschrieben (siehe
// lib/libs/plan_widgets.dart); auf die Uhr kommen sie über WatchSyncBridge/WatchSync.
//
// Die Datei wird in die iOS-Widget-Extension, die watchOS-Widget-Extension und die Watch-App
// kompiliert. Datenmodell, Laden (PlanStore), Block-Logik und Kalender-Helfer hier nutzen deshalb
// auch die Homescreen-Widgets (KeplerHomeWidgets.swift) und die Watch-App (DayPlanScreen.swift).

import AppIntents
import WidgetKit
import SwiftUI

// MARK: - Konfiguration

/// muss mit iosWidgetAppGroupId in plan_widgets.dart, den .entitlements und der Kopie in
/// WatchSyncBridge.swift übereinstimmen
let appGroupId = "group.de.kepler-chemnitz.keplerapp"
/// Key, unter dem die Flutter-App den Tagesplan als JSON speichert
let dataKey = "data"
/// Key des Plans für den nächsten Schultag
let nextDataKey = "data_next"
/// Key der Namen aller ausgewählten Pläne (JSON-Liste, primärer zuerst), geschrieben von der App
let planNamesKey = "plan_names"

// MARK: - Datenmodell

/// eine einzelne Stunde aus dem geteilten Plan
struct WidgetLesson {
    let schoolHour: Int
    let subject: String
    let rooms: [String]
    let teacher: String
    let info: String
    let start: Date?
    let end: Date?
    let subjectChanged: Bool
    let roomChanged: Bool
    let teacherChanged: Bool
    /// bei zusammengefassten Doppelstunden die letzte Stunde des Blocks (sonst nil)
    var lastSchoolHour: Int? = nil
    /// synthetischer Eintrag für eine Freistunde (Lücke zwischen zwei Blöcken)
    var isFree: Bool = false

    var changed: Bool { subjectChanged || roomChanged || teacherChanged }
    var roomText: String { rooms.filter { !$0.isEmpty }.joined(separator: ", ") }
    /// Ausfall: kein echtes Fach (leer oder "---"), aber keine Freistunde
    var isCancelled: Bool { !isFree && (subject.isEmpty || subject == "---") }

    /// kompakte Stundenangabe: "1." bzw. "4.–5." bei zusammengefassten Blöcken
    var hourLabel: String {
        if let last = lastSchoolHour, last > schoolHour { return "\(schoolHour).–\(last)." }
        return "\(schoolHour)."
    }

    /// läuft die Stunde zum Zeitpunkt `date` (Beginn <= date < Ende)? Ohne Uhrzeiten nie.
    func isRunning(at date: Date) -> Bool {
        guard let s = start, let e = end else { return false }
        return s <= date && date < e
    }
}

/// Primärfarbe der App (keplerColorBlue, #4A8ABA) - Akzent der Homescreen-Widgets und der Watch-App
let keplerBlue = Color(red: 74 / 255, green: 138 / 255, blue: 186 / 255)

/// fasst aufeinanderfolgende Stunden mit identischem Fach/Raum/Lehrer (und gleichem Änderungsstatus)
/// zu einem Block zusammen (Doppel-/Mehrfachstunden). Erwartet nach schoolHour sortierte Stunden.
///
/// Gesucht wird der passende Block in allen bisherigen, nicht nur im zuletzt angelegten: Belegen
/// mehrere Kurse dieselbe Stunde (z.B. LA und FR jeweils in der 2. und 3. Stunde), liegt die
/// Fortsetzung eines Kurses nicht direkt hinter ihm, sondern erst nach den parallelen Kursen.
func mergeDoublePeriods(_ lessons: [WidgetLesson]) -> [WidgetLesson] {
    var result: [WidgetLesson] = []
    for lesson in lessons {
        let match = result.lastIndex { block in
            block.subject == lesson.subject
                && block.rooms == lesson.rooms
                && block.teacher == lesson.teacher
                && block.subjectChanged == lesson.subjectChanged
                && block.roomChanged == lesson.roomChanged
                && block.teacherChanged == lesson.teacherChanged
                && lesson.schoolHour == (block.lastSchoolHour ?? block.schoolHour) + 1
        }
        if let i = match {
            // an den Block anhängen: Endzeit & letzte Stunde übernehmen
            let block = result[i]
            result[i] = WidgetLesson(
                schoolHour: block.schoolHour, subject: block.subject, rooms: block.rooms,
                teacher: block.teacher, info: block.info.isEmpty ? lesson.info : block.info,
                start: block.start, end: lesson.end,
                subjectChanged: block.subjectChanged, roomChanged: block.roomChanged,
                teacherChanged: block.teacherChanged, lastSchoolHour: lesson.schoolHour)
        } else {
            result.append(lesson)
        }
    }
    return result
}

/// fügt eine Freistunde ein, wo vor einem Block keine Stunde belegt ist. Erwartet nach Beginn
/// (schoolHour) sortierte Blöcke.
///
/// Verglichen wird mit der bisher höchsten belegten Stunde aller vorigen Blöcke, nicht nur mit dem
/// direkten Vorgänger: Bei parallelen Kursen ungleicher Länge (z.B. LA 2.–3., FR nur 2., danach
/// Ma 4.) ist die 3. Stunde durch LA belegt, obwohl FR schon nach der 2. endet. Die Freistunde
/// spannt vom spätesten Ende der vorigen Blöcke bis zum Beginn des nächsten.
func insertFreePeriods(_ blocks: [WidgetLesson]) -> [WidgetLesson] {
    guard let first = blocks.first else { return blocks }
    var result: [WidgetLesson] = [first]
    var lastHour = first.lastSchoolHour ?? first.schoolHour
    var lastEnd = first.end
    for block in blocks.dropFirst() {
        if block.schoolHour > lastHour + 1 {
            let freeFirst = lastHour + 1
            let freeLast = block.schoolHour - 1
            result.append(WidgetLesson(
                schoolHour: freeFirst, subject: "", rooms: [], teacher: "", info: "",
                start: lastEnd, end: block.start,
                subjectChanged: false, roomChanged: false, teacherChanged: false,
                lastSchoolHour: freeLast > freeFirst ? freeLast : nil, isFree: true))
        }
        result.append(block)
        lastHour = max(lastHour, block.lastSchoolHour ?? block.schoolHour)
        if let e = block.end, lastEnd.map({ e > $0 }) ?? true { lastEnd = e }
    }
    return result
}

/// geparster Tagesplan für den im Widget ausgewählten Plan (Standard: plans[0])
struct PlanData {
    let dateString: String
    let holiday: Bool
    let className: String
    let lessons: [WidgetLesson]

    /// die zum Zeitpunkt `date` laufende Stunde (bei parallelen Kursen die erste)
    func runningLesson(at date: Date) -> WidgetLesson? {
        lessons.first { $0.isRunning(at: date) }
    }

    /// alle Stunden, die nach `date` beginnen, nach Beginn sortiert
    func upcomingLessons(after date: Date) -> [WidgetLesson] {
        lessons.filter { ($0.start ?? .distantPast) > date }
            .sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }

    /// Fallback für Pläne ohne Uhrzeiten (Indiware ohne Stundenraster -> start/end == nil): Dann gibt
    /// es über Zeitvergleiche keine aktuelle/nächste Stunde, und die Widgets zeigen die Stunden der
    /// Reihe nach. Leer, sobald auch nur eine Stunde eine Beginnzeit hat.
    var untimedLessons: [WidgetLesson] {
        lessons.allSatisfy { $0.start == nil } ? lessons : []
    }
}

// MARK: - Laden & Parsen

/// "HH:mm" am angegebenen Tag in ein Date umwandeln
private func parseTime(_ value: Any?, on day: Date) -> Date? {
    guard let s = value as? String else { return nil }
    let parts = s.split(separator: ":")
    guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
    return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: day)
}

/// parst einen Plan-JSON-String (Format siehe plan_widgets.dart); gibt nil zurück, wenn keine
/// (gültigen) Daten vorhanden sind. Die Uhrzeiten der Stunden werden auf den Kalendertag von
/// `referenceDate` gelegt.
///
/// `planName` wählt den anzuzeigenden Plan (siehe PlanSelection.swift). Ohne Angabe – oder wenn der
/// gewählte Plan nicht mehr existiert, weil die Klasse in der App abgewählt wurde – wird der primär
/// ausgewählte Plan (plans[0]) verwendet.
///
/// Gelesen wird über `PlanStore`, der jeden Plan nur einmal aus der App-Group holt und parst.
private func parsePlanData(_ jsonString: String?, referenceDate: Date, planName: String?) -> PlanData? {
    guard let jsonString,
          let jsonData = jsonString.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
    else { return nil }

    let dateString = root["date"] as? String ?? ""
    let holiday = root["holiday"] as? Bool ?? false
    guard let plans = root["plans"] as? [Any] else {
        return PlanData(dateString: dateString, holiday: holiday, className: "", lessons: [])
    }

    // gewünschten Plan über den Namen suchen, sonst den primären nehmen
    let selected: [Any]? = planName
        .flatMap { name in
            plans.compactMap { $0 as? [Any] }.first { ($0.first as? String) == name }
        } ?? plans.first as? [Any]

    guard let first = selected, !first.isEmpty else {
        return PlanData(dateString: dateString, holiday: holiday, className: "", lessons: [])
    }

    let className = first.first as? String ?? ""
    let day = Calendar.current.startOfDay(for: referenceDate)
    var lessons: [WidgetLesson] = []
    for element in first.dropFirst() {
        guard let l = element as? [String: Any] else { continue }
        // Marker für ausgeblendete Stunden ("hidden") überspringen
        if l["hidden"] != nil { continue }
        let changed = l["changed"] as? [String: Any] ?? [:]
        lessons.append(WidgetLesson(
            schoolHour: l["schoolHour"] as? Int ?? 0,
            subject: l["subject"] as? String ?? "",
            rooms: (l["rooms"] as? [Any])?.compactMap { $0 as? String } ?? [],
            teacher: l["teacher"] as? String ?? "",
            info: l["info"] as? String ?? "",
            start: parseTime(l["start"], on: day),
            end: parseTime(l["end"], on: day),
            subjectChanged: changed["subject"] as? Bool ?? false,
            roomChanged: changed["rooms"] as? Bool ?? false,
            teacherChanged: changed["teacher"] as? Bool ?? false
        ))
    }
    lessons.sort { $0.schoolHour < $1.schoolHour }
    lessons = mergeDoublePeriods(lessons)
    lessons = insertFreePeriods(lessons)
    return PlanData(dateString: dateString, holiday: holiday, className: className, lessons: lessons)
}

/// Liest die geteilten Pläne für eine zusammenhängende Berechnung (z.B. eine ganze Timeline) nur
/// einmal aus der App-Group und parst jeden Plan je Kalendertag nur einmal. Ohne das las und parste
/// jeder Timeline-Eintrag die Daten erneut (bei bis zu 150 Einträgen der Homescreen-Widgets).
///
/// Nur kurzlebig verwenden (pro Timeline bzw. pro Berechnung): Änderungen in der App-Group, die
/// danach eintreffen, sieht ein bestehender Store nicht.
final class PlanStore {
    let planName: String?
    /// Formatter für den Datumsvergleich ("dd-MM-yyyy"), einmal pro Store statt pro Abfrage
    let dateFormatter = widgetDateFormatter()
    private var raw: [String: String?] = [:]
    private var parsed: [String: PlanData?] = [:]

    init(planName: String? = nil) {
        self.planName = planName
    }

    /// liest und parst den geteilten Plan unter `key` ("data" oder "data_next" = nächster Schultag)
    /// für den Kalendertag von `referenceDate` (Details siehe `parsePlanData`), zwischengespeichert
    func plan(_ key: String, on referenceDate: Date) -> PlanData? {
        let day = Calendar.current.startOfDay(for: referenceDate)
        let cacheKey = "\(key)|\(day.timeIntervalSinceReferenceDate)"
        if let hit = parsed[cacheKey] { return hit }
        let json: String?
        if let cached = raw[key] {
            json = cached
        } else {
            json = UserDefaults(suiteName: appGroupId)?.string(forKey: key)
            raw[key] = json
        }
        let result = parsePlanData(json, referenceDate: day, planName: planName)
        parsed[cacheKey] = result
        return result
    }

    /// der Plan für den Kalendertag von `now`: "data"; ist der veraltet (z.B. früh am Morgen, bevor
    /// die App lief), "data_next" - das kann inzwischen "heute" geworden sein. nil, wenn keiner der
    /// beiden für heute gilt. Prüft NICHT auf Wochenende.
    func todayPlan(at now: Date) -> PlanData? {
        let today = dateFormatter.string(from: now)
        if let p = plan(dataKey, on: now), p.dateString == today { return p }
        if let np = plan(nextDataKey, on: now), np.dateString == today { return np }
        return nil
    }

    /// der nächste Schultag nach `now` samt Plan aus "data_next" (nil, wenn der nicht für genau diesen
    /// Tag gilt) und Beschriftung ("Morgen" bzw. Wochentag)
    func nextSchoolDay(after now: Date) -> (date: Date, label: String, plan: PlanData?) {
        let cal = Calendar.current
        let next = keplerNextSchoolDay(after: now)
        let tomorrow = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        let label = cal.isDate(next, inSameDayAs: tomorrow) ? "Morgen" : keplerGermanWeekday(next)
        let p = plan(nextDataKey, on: next)
        return (next, label, p?.dateString == dateFormatter.string(from: next) ? p : nil)
    }
}

// MARK: - Kalender-Helfer

/// Samstag oder Sonntag
func keplerIsWeekend(_ date: Date) -> Bool {
    let weekday = Calendar.current.component(.weekday, from: date)
    return weekday == 1 || weekday == 7
}

/// Beginn des nächsten Tages nach `now`, der kein Wochenende ist (Ferien bleiben unberücksichtigt)
func keplerNextSchoolDay(after now: Date) -> Date {
    let cal = Calendar.current
    var d = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
    while keplerIsWeekend(d) {
        d = cal.date(byAdding: .day, value: 1, to: d) ?? d
    }
    return d
}

/// deutscher Wochentagsname ("Montag" …)
func keplerGermanWeekday(_ date: Date) -> String {
    let names = ["", "Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"]
    return names[Calendar.current.component(.weekday, from: date)]
}

// MARK: - Zustand

/// Beschreibung der anzuzeigenden Stunde (für die Views vorbereitet)
struct LessonDisplay {
    let relation: String   // "Jetzt", "Als Nächstes" oder "Heute" (Plan ohne Uhrzeiten)
    let hourText: String   // z.B. "1. Stunde" / "2.–3. Stunde"
    let hourShort: String  // z.B. "1. St" / "2.–3. St" (für das runde Widget)
    let timeText: String   // z.B. "7:35 – 8:20"
    let subject: String
    let room: String
    let teacher: String
    let info: String
    let cancelled: Bool    // Ausfall
    let free: Bool         // Freistunde
    var subjectChanged = false
    var roomChanged = false
    var teacherChanged = false

    /// irgendeine Abweichung vom Regelplan (Ausfall zählt mit) - steuert das Warnsymbol
    var changed: Bool { cancelled || subjectChanged || roomChanged || teacherChanged }
}

/// Warnsymbol für geänderte Angaben. Auf dem Sperrbildschirm und dem Zifferblatt stellt das System
/// alles einfarbig dar - eine Farbmarkierung wie in den Homescreen-Widgets ginge dort verloren.
let keplerChangedSymbol = "exclamationmark.triangle.fill"

enum WidgetState {
    case lesson(LessonDisplay)
    case message(symbol: String, title: String, subtitle: String)
}

struct LessonEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
}

/// formatiert eine Uhrzeit als "H:mm" (24 Stunden, Stunde ohne führende Null, z.B. "7:45").
/// Bewusst über die Kalenderkomponenten statt über einen DateFormatter: Das ist unabhängig von der
/// 12-/24-Stunden-Einstellung des Geräts und erspart das (teure) Anlegen eines Formatters für jede
/// Uhrzeit einer Timeline.
func keplerTimeString(_ date: Date?) -> String {
    guard let date = date else { return "" }
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    return String(format: "%d:%02d", c.hour ?? 0, c.minute ?? 0)
}

private func fmt(_ date: Date?) -> String { keplerTimeString(date) }

private func display(for lesson: WidgetLesson, relation: String) -> LessonDisplay {
    let timeText: String
    if let s = lesson.start, let e = lesson.end {
        timeText = "\(fmt(s)) – \(fmt(e))"
    } else if let s = lesson.start {
        timeText = fmt(s)
    } else {
        timeText = ""
    }
    let subject: String
    if lesson.isFree {
        subject = "Freistunde"
    } else if lesson.isCancelled {
        subject = "Ausfall"
    } else {
        subject = lesson.subject
    }
    return LessonDisplay(
        relation: relation,
        hourText: lesson.hourLabel + " Stunde",
        hourShort: lesson.hourLabel + " St",
        timeText: timeText,
        subject: subject,
        room: lesson.roomText,
        teacher: lesson.teacher,
        info: lesson.info,
        cancelled: lesson.isCancelled,
        free: lesson.isFree,
        subjectChanged: lesson.subjectChanged,
        roomChanged: lesson.roomChanged,
        teacherChanged: lesson.teacherChanged
    )
}

/// bestimmt die anzuzeigende Stunde (laufend oder als nächstes) zum Zeitpunkt `date`
private func stateAt(_ date: Date, plan: PlanData) -> WidgetState {
    // laufende Stunde (start <= jetzt < ende)
    if let current = plan.runningLesson(at: date) {
        return .lesson(display(for: current, relation: "Jetzt"))
    }
    return nextStateAt(date, plan: plan)
}

/// bestimmt immer die *nächste* anstehende Stunde (Start in der Zukunft) - ignoriert die gerade
/// laufende Stunde. Für das „Nächste Stunde"-Widget (parallel zum „Aktuelle Stunde"-Widget) und
/// für „Aktuelle Stunde", wenn gerade keine Stunde läuft.
private func nextStateAt(_ date: Date, plan: PlanData) -> WidgetState {
    if let next = plan.upcomingLessons(after: date).first {
        return .lesson(display(for: next, relation: "Als Nächstes"))
    }
    // keine Stunden mit Zeiten? -> erste Stunde des Tages zeigen (Fallback ohne Zeitlogik)
    if let first = plan.untimedLessons.first {
        return .lesson(display(for: first, relation: "Heute"))
    }
    // nach Schulschluss: „Frei für heute" mit Haken
    return .message(symbol: "checkmark.circle", title: "Frei", subtitle: "für heute")
}

/// DateFormatter mit festem gregorianischem Kalender + POSIX-Locale, passend zum Dart-Writer
/// (`dd-MM-yyyy`). Ohne das würden nicht-gregorianische Geräte-Kalender (z.B. Buddhistisch,
/// Japanisch) die Datumsvergleiche brechen und die Widgets dauerhaft "Bitte App öffnen" zeigen.
/// Erzeugt bei jedem Aufruf einen neuen Formatter - für wiederholte Vergleiche einmal anlegen
/// (siehe PlanStore).
func widgetDateFormatter() -> DateFormatter {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.calendar = Calendar(identifier: .gregorian)
    df.timeZone = .current
    df.dateFormat = "dd-MM-yyyy"
    return df
}

// MARK: - Provider

/// welche Stunde ein Provider zeigt: laufende-oder-nächste (Aktuelle Stunde) bzw. nur nächste
enum LessonMode { case currentOrNext, nextOnly }

/// Beispiel-Eintrag für Platzhalter und Vorschau (beide Plattformen)
func keplerPlaceholderEntry() -> LessonEntry {
    LessonEntry(date: Date(), state: .lesson(LessonDisplay(
        relation: "Als Nächstes", hourText: "1. Stunde", hourShort: "1.", timeText: "7:35 – 8:20",
        subject: "Ma", room: "153", teacher: "Alb", info: "", cancelled: false, free: false)))
}

/// Beginn des Tages nach `now` (Mitternacht)
func keplerNextMidnight(after now: Date) -> Date {
    let cal = Calendar.current
    return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
}

/// nächster Neuladezeitpunkt: kurz nach Mitternacht. Ab dann gilt der neue Tag - "data" ist
/// veraltet, und PlanStore.todayPlan greift auf "data_next" zurück, falls die App den Plan des
/// neuen Tags schon geladen hat. Die halbe Minute Abstand stellt sicher, dass `Date()` beim
/// Neuladen sicher im neuen Tag liegt. Bis dahin überbrückt ein Eintrag um Mitternacht (siehe
/// keplerTimelineEntries bzw. HomeProvider.timelineEntries), denn WidgetKit lädt nicht
/// sekundengenau neu.
func keplerNextReload(after now: Date) -> Date {
    keplerNextMidnight(after: now).addingTimeInterval(30)
}

#if os(iOS)
struct Provider: AppIntentTimelineProvider {
    var mode: LessonMode = .currentOrNext

    func placeholder(in context: Context) -> LessonEntry { keplerPlaceholderEntry() }

    func snapshot(for configuration: PlanSelectionIntent, in context: Context) async -> LessonEntry {
        keplerMakeEntries(now: Date(), planName: configuration.plan?.id, mode: mode).first
            ?? placeholder(in: context)
    }

    func timeline(for configuration: PlanSelectionIntent, in context: Context) async -> Timeline<LessonEntry> {
        let now = Date()
        return Timeline(entries: keplerTimelineEntries(now: now, planName: configuration.plan?.id, mode: mode),
                        policy: .after(keplerNextReload(after: now)))
    }
}
#endif

#if os(watchOS)
/// Key des in der Watch-App gewählten Plans (Name); fehlt er, gilt der primäre Plan
let watchPlanKey = "watch_plan"

/// der in der Watch-App gewählte Plan, nil = primärer Plan (plans[0])
func keplerWatchSelectedPlan() -> String? {
    let name = UserDefaults(suiteName: appGroupId)?.string(forKey: watchPlanKey) ?? ""
    return name.isEmpty ? nil : name
}

/// Auf der Uhr zeigen die Complications den in der Watch-App gewählten Plan (siehe DayPlanScreen),
/// sonst den primären. Die Auswahl liegt in der App-Group der Uhr statt in einer Widget-
/// Konfiguration - deshalb StaticConfiguration statt AppIntentConfiguration. Das hält das
/// Deployment-Target bei watchOS 9 (AppIntentConfiguration verlangt watchOS 10) und deckt damit
/// Series 4 und neuer ab.
struct WatchProvider: TimelineProvider {
    var mode: LessonMode = .currentOrNext

    func placeholder(in context: Context) -> LessonEntry { keplerPlaceholderEntry() }

    func getSnapshot(in context: Context, completion: @escaping (LessonEntry) -> Void) {
        completion(keplerMakeEntries(now: Date(), planName: keplerWatchSelectedPlan(), mode: mode).first
            ?? keplerPlaceholderEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LessonEntry>) -> Void) {
        let now = Date()
        completion(Timeline(entries: keplerTimelineEntries(now: now, planName: keplerWatchSelectedPlan(), mode: mode),
                            policy: .after(keplerNextReload(after: now))))
    }
}
#endif

// MARK: - Plannamen

/// Namen aller ausgewählten Pläne in der Reihenfolge der App (Index 0 = primärer Plan). Bevorzugt
/// die Liste unter planNamesKey - sie ist unabhängig davon, ob es für einen Tag einen Plan gibt
/// (Wochenende, Ferien, noch nicht veröffentlicht). Fehlt sie, z.B. weil die App seit dem Update
/// noch nicht lief, werden die Namen aus "data" und danach "data_next" genommen.
func keplerPlanNames() -> [String] {
    let defaults = UserDefaults(suiteName: appGroupId)
    if let json = defaults?.string(forKey: planNamesKey),
       let data = json.data(using: .utf8),
       let names = try? JSONSerialization.jsonObject(with: data) as? [String],
       !names.isEmpty {
        return names
    }
    for key in [dataKey, nextDataKey] {
        guard let jsonString = defaults?.string(forKey: key),
              let jsonData = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let plans = root["plans"] as? [Any]
        else { continue }
        let names = plans.compactMap { ($0 as? [Any])?.first as? String }
        if !names.isEmpty { return names }
    }
    return []
}

// MARK: - Plattformunterschiede

/// unterstützte Familien: auf der Uhr kommt die Ecken-Complication dazu, die es auf iOS nicht gibt
let keplerAccessoryFamilies: [WidgetFamily] = {
    #if os(watchOS)
    return [.accessoryRectangular, .accessoryInline, .accessoryCircular, .accessoryCorner]
    #else
    return [.accessoryRectangular, .accessoryInline, .accessoryCircular]
    #endif
}()

/// Hinweis bei fehlenden Daten - auf der Uhr muss die iPhone-App geöffnet werden, nicht die Uhr-App
#if os(watchOS)
let keplerOpenAppHint = "Am iPhone öffnen"
#else
let keplerOpenAppHint = "Bitte App öffnen"
#endif

// MARK: - Timeline-Aufbau (plattformunabhängig)

/// baut die Timeline-Einträge der Sperrbildschirm-Widgets bzw. Complications - je ein Eintrag an
/// jeder Stunden-Grenze, damit das Widget über den Tag automatisch weiterspringt, ohne dass die App
/// geöffnet werden muss
func keplerMakeEntries(now: Date, planName: String?, mode: LessonMode) -> [LessonEntry] {
    // Sonderfälle zuerst (jeweils nur ein Eintrag für „jetzt")
    if keplerIsWeekend(now) {
        return [LessonEntry(date: now, state: .message(symbol: "calendar", title: "Wochenende", subtitle: "Heute keine Schule"))]
    }
    // "data", ersatzweise "data_next", falls das inzwischen "heute" ist (gleiche Auswahl wie bei
    // den Homescreen-Widgets und der Watch-App, siehe PlanStore.todayPlan)
    let store = PlanStore(planName: planName)
    guard let plan = store.todayPlan(at: now) else {
        // gar kein Plan vs. nur ein veralteter Plan in "data"
        let state: WidgetState = store.plan(dataKey, on: now) == nil
            ? .message(symbol: "iphone", title: "Keine Daten", subtitle: keplerOpenAppHint)
            : .message(symbol: "iphone", title: "Plan veraltet", subtitle: keplerOpenAppHint)
        return [LessonEntry(date: now, state: state)]
    }
    if plan.holiday {
        return [LessonEntry(date: now, state: .message(symbol: "sun.max", title: "Frei", subtitle: "Heute kein Unterricht"))]
    }
    if plan.lessons.isEmpty {
        return [LessonEntry(date: now, state: .message(symbol: "tray", title: "Kein Plan", subtitle: keplerOpenAppHint))]
    }

    // Grenzen sammeln: jetzt + alle zukünftigen Start-/Endzeiten
    var boundaries: [Date] = [now]
    for l in plan.lessons {
        if let s = l.start, s > now { boundaries.append(s) }
        if let e = l.end, e > now { boundaries.append(e) }
    }
    let uniqueSorted = Array(Set(boundaries)).sorted()

    let stateFn: (Date, PlanData) -> WidgetState = (mode == .nextOnly) ? nextStateAt : stateAt
    return uniqueSorted.map { LessonEntry(date: $0, state: stateFn($0, plan)) }
}

/// alle Einträge einer Timeline: die des laufenden Tags (keplerMakeEntries) und dazu der erste
/// Eintrag des neuen Tags um Mitternacht. Ohne ihn stünde nach Mitternacht bis zum Neuladen noch
/// der Stand des Vortags da (z.B. „Frei für heute“).
func keplerTimelineEntries(now: Date, planName: String?, mode: LessonMode) -> [LessonEntry] {
    let midnight = keplerNextMidnight(after: now)
    var entries = keplerMakeEntries(now: now, planName: planName, mode: mode)
    if let first = keplerMakeEntries(now: midnight, planName: planName, mode: mode).first {
        entries.append(first)
    }
    return entries
}

// MARK: - Views

private extension View {
    /// Ab iOS 17 müssen auch Sperrbildschirm-Widgets einen containerBackground deklarieren,
    /// sonst zeigt das System nur "Please adopt containerBackground API". Auf watchOS gibt es
    /// die API erst ab 10.0 - dort ist sie bis 9.x weder verfügbar noch nötig.
    /// Der Hintergrund bleibt in beiden Fällen transparent.
    @ViewBuilder func keplerWidgetContainerBackground() -> some View {
        #if os(watchOS)
        if #available(watchOS 10.0, *) {
            containerBackground(.clear, for: .widget)
        } else {
            self
        }
        #else
        containerBackground(.clear, for: .widget)
        #endif
    }
}


struct KeplerLockWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: LessonEntry

    var body: some View {
        content.keplerWidgetContainerBackground()
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline:
            inlineView
        case .accessoryCircular:
            circularView
        #if os(watchOS)
        // ohne eigenen Zweig landet die Ecken-Complication im default und rendert das
        // dreizeilige Rechteck-Layout in ein ~38x38pt-Eckfeld
        case .accessoryCorner:
            cornerView
        #endif
        default:
            rectangularView
        }
    }

    #if os(watchOS)
    /// Ecken-Complication (Infograph): Fachkürzel in der Ecke, Zeit als gebogener Randtext
    @ViewBuilder private var cornerView: some View {
        switch entry.state {
        case .lesson(let l):
            Group {
                // bei Ausfall das Warnsymbol statt eines Fachs
                if l.cancelled {
                    Image(systemName: keplerChangedSymbol)
                } else {
                    Text(l.free ? "Frei" : l.subject)
                }
            }
                .font(.system(size: 15, weight: .semibold))
                .minimumScaleFactor(0.6)
                .widgetLabel {
                    // Den gebogenen Randtext zeichnet watchOS nur aus reinem Text - ein per
                    // Interpolation eingebettetes SF-Symbol fällt dort stillschweigend weg.
                    // Deshalb das Warnzeichen als Schriftzeichen (U+26A0 mit Text-Variante).
                    Text((l.changed ? "\u{26A0}\u{FE0E} " : "")
                         + (l.room.isEmpty ? l.timeText : "\(l.room) · \(l.timeText)"))
                }
        case .message(let symbol, let title, _):
            Image(systemName: symbol)
                .font(.system(size: 15))
                .widgetLabel { Text(title) }
        }
    }
    #endif

    // Rechteckig: Hauptformat mit Fach, Raum und Lehrer
    @ViewBuilder private var rectangularView: some View {
        switch entry.state {
        case .lesson(let l):
            VStack(alignment: .leading, spacing: 1) {
                Text("\(l.relation) · \(l.hourText)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    if l.cancelled || l.subjectChanged {
                        Image(systemName: keplerChangedSymbol).font(.system(size: 13))
                    }
                    Text(l.subject)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .widgetAccentable()
                if l.cancelled {
                    // bei Ausfall: hinschreiben, was ausfällt (Info-Text statt Raum/Lehrer)
                    if !l.info.isEmpty {
                        Text(l.info)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                } else if !l.free {
                    // normale Stunde: Raum + Lehrer (Freistunde zeigt nichts weiter)
                    HStack(spacing: 5) {
                        if !l.room.isEmpty {
                            Label(l.room, systemImage: l.roomChanged ? keplerChangedSymbol : "mappin.and.ellipse")
                        }
                        if !l.teacher.isEmpty {
                            Label(l.teacher, systemImage: l.teacherChanged ? keplerChangedSymbol : "person.fill")
                        }
                    }
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        case .message(let symbol, let title, let subtitle):
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .widgetAccentable()
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }

    // Inline: einzeilig über der Uhrzeit (Sperrbildschirm) bzw. am Zifferblatt
    @ViewBuilder private var inlineView: some View {
        switch entry.state {
        case .lesson(let l):
            if l.cancelled {
                Label("Ausfall", systemImage: "exclamationmark.triangle.fill")
            } else if l.free {
                Label("Freistunde", systemImage: "cup.and.saucer")
            } else {
                Label([l.subject, l.room, l.teacher].filter { !$0.isEmpty }.joined(separator: " · "),
                      systemImage: l.changed ? keplerChangedSymbol : "book.closed")
            }
        case .message(let symbol, let title, _):
            Label(title, systemImage: symbol)
        }
    }

    // Kreis: Stunde, Fachkürzel und Raum
    @ViewBuilder private var circularView: some View {
        switch entry.state {
        case .lesson(let l):
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    HStack(spacing: 1) {
                        if l.changed && !l.cancelled {
                            Image(systemName: keplerChangedSymbol)
                        }
                        Text(l.hourShort)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    Text(l.free ? "Frei" : l.subject)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .widgetAccentable()
                    if !l.cancelled && !l.free && !l.room.isEmpty {
                        Text(l.room)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(2)
            }
        case .message(let symbol, _, _):
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: symbol).font(.system(size: 18))
            }
        }
    }
}

// MARK: - Widget

struct KeplerLockWidget: Widget {
    let kind = "KeplerLockWidget"

    var body: some WidgetConfiguration {
        #if os(watchOS)
        return StaticConfiguration(kind: kind, provider: WatchProvider(mode: .currentOrNext)) { entry in
            KeplerLockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Aktuelle Stunde")
        .description("Zeigt Fach, Raum und Lehrer der aktuellen (bzw. nächsten) Stunde aus deinem Plan.")
        .supportedFamilies(keplerAccessoryFamilies)
        #else
        return AppIntentConfiguration(kind: kind, intent: PlanSelectionIntent.self,
                                      provider: Provider(mode: .currentOrNext)) { entry in
            KeplerLockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Aktuelle Stunde")
        .description("Zeigt Fach, Raum und Lehrer der aktuellen (bzw. nächsten) Stunde aus deinem Plan.")
        .supportedFamilies(keplerAccessoryFamilies)
        #endif
    }
}

struct KeplerNextLockWidget: Widget {
    let kind = "KeplerNextLockWidget"

    var body: some WidgetConfiguration {
        #if os(watchOS)
        return StaticConfiguration(kind: kind, provider: WatchProvider(mode: .nextOnly)) { entry in
            KeplerLockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Nächste Stunde")
        .description("Zeigt Fach, Raum und Lehrer der nächsten anstehenden Stunde aus deinem Plan.")
        .supportedFamilies(keplerAccessoryFamilies)
        #else
        return AppIntentConfiguration(kind: kind, intent: PlanSelectionIntent.self,
                                      provider: Provider(mode: .nextOnly)) { entry in
            KeplerLockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Nächste Stunde")
        .description("Zeigt Fach, Raum und Lehrer der nächsten anstehenden Stunde aus deinem Plan.")
        .supportedFamilies(keplerAccessoryFamilies)
        #endif
    }
}
