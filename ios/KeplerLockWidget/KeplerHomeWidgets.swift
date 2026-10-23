// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2026 Jakob Krause
//
// This file is part of kepler_app. It is licensed under the GNU GPLv3.
// See the LICENSE file in the repository root for details.
//
// Homescreen-Widgets (systemSmall/systemMedium) im App-Stil: aktuelle Stunde, nächste Stunde
// und Tagesplan-Liste. Datenmodell, Laden (PlanStore), Block-Logik und Kalender-Helfer kommen aus
// KeplerLockWidget.swift.

import AppIntents
import WidgetKit
import SwiftUI
import UIKit

// MARK: - Helfer

// Akzentfarbe: keplerBlue (KeplerLockWidget.swift)

/// Uhrzeit als "HH:mm" (mit führender Null, anders als keplerTimeString)
private func homeHM(_ d: Date) -> String {
    let c = Calendar.current.dateComponents([.hour, .minute], from: d)
    return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
}

private enum HomeRelation { case now, next, later, today }

/// neutraler Hintergrund: weiß (hell) / dunkelgrau (dunkel)
private extension Color {
    static var widgetBg: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.11, alpha: 1) : .white })
    }
}

private extension View {
    /// containerBackground ist ab iOS 17 Pflicht; die Extension setzt iOS 17 voraus
    func widgetBackground(_ bg: Color) -> some View {
        containerBackground(bg, for: .widget)
    }
}

// MARK: - Bausteine

/// Im eingefärbten und im transparenten Modus färbt iOS das Widget einheitlich ein - das Rot für
/// Änderungen geht dort verloren. Dann steht stattdessen das Warndreieck vor der Angabe, wie auf
/// dem Sperrbildschirm. Im Standardmodus bleibt es beim Rot.
private func changeMarked(_ text: Text, _ changed: Bool, _ mode: WidgetRenderingMode) -> Text {
    guard changed && mode != .fullColor else { return text }
    return Text("\(Image(systemName: keplerChangedSymbol)) \(text)")
}

private struct LessonCard: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let lesson: WidgetLesson
    let relation: HomeRelation
    let now: Date

    private var badgeText: String {
        switch relation { case .now: return "Jetzt"; case .later: return "Danach"; case .today: return "Heute"; case .next: return "Nächste" }
    }
    private var badgeColor: Color { relation == .now ? keplerBlue : .gray }

    /// Außerhalb des Vollfarb-Modus (z.B. getönter oder transparenter Homescreen) färbt das System
    /// alle Inhalte einfarbig ein. Weiße Schrift auf gefüllter Fläche wäre dann unsichtbar - dort
    /// also Kontur statt Füllung und die normale Vordergrundfarbe.
    @ViewBuilder private var badge: some View {
        let label = Text(badgeText).font(.system(size: 12, weight: .semibold))
        if renderingMode == .fullColor {
            label.foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(badgeColor, in: Capsule())
        } else {
            label.padding(.horizontal, 8).padding(.vertical, 3)
                .overlay(Capsule().stroke(.primary.opacity(0.7), lineWidth: 1))
        }
    }
    private var subjectText: String { lesson.isFree ? "Freistunde" : (lesson.isCancelled ? "Ausfall" : lesson.subject) }
    private var progress: Double {
        guard let s = lesson.start, let e = lesson.end, e > s else { return 0 }
        return min(1, max(0, now.timeIntervalSince(s) / e.timeIntervalSince(s)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                badge
                Spacer(minLength: 0)
                Text(lesson.hourLabel + " Std").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .leading, spacing: 1) {
                changeMarked(Text(subjectText), lesson.subjectChanged || lesson.isCancelled, renderingMode)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(lesson.subjectChanged ? .red : .primary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if lesson.isCancelled {
                    if !lesson.info.isEmpty {
                        Text(lesson.info).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                    }
                } else if !lesson.isFree {
                    if !lesson.roomText.isEmpty {
                        changeMarked(Text(lesson.roomText), lesson.roomChanged, renderingMode)
                            .font(.system(size: 15)).foregroundStyle(lesson.roomChanged ? .red : .primary)
                    }
                    if !lesson.teacher.isEmpty {
                        changeMarked(Text(lesson.teacher), lesson.teacherChanged, renderingMode)
                            .font(.system(size: 14)).italic().foregroundStyle(lesson.teacherChanged ? .red : .secondary)
                    }
                }
            }
            Spacer(minLength: 4)
            if let s = lesson.start, let e = lesson.end {
                HStack(spacing: 6) {
                    Text(homeHM(s)).font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                    if relation == .now { ProgressTrack(value: progress) } else { Spacer(minLength: 0) }
                    Text(homeHM(e)).font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct ProgressTrack: View {
    let value: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.25)).frame(height: 3)
                Capsule().fill(keplerBlue).frame(width: max(0, g.size.width * value), height: 3)
                Circle().fill(keplerBlue).frame(width: 9, height: 9).offset(x: max(0, g.size.width * value - 4.5))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 12)
    }
}

/// 2-Buchstaben-Wochentagskürzel (Mo/Di/…) aus dem Plan-Datum ("dd-MM-yyyy");
/// nur einmal pro Darstellung aufgerufen, daher ohne zwischengespeicherten Formatter
private func weekdayAbbrevHome(_ dateString: String) -> String {
    guard let d = widgetDateFormatter().date(from: dateString) else { return "" }
    let names = ["", "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
    return names[Calendar.current.component(.weekday, from: d)]
}

private struct DayList: View {
    @Environment(\.widgetFamily) private var family
    let plan: PlanData
    let now: Date
    var dayLabel: String? = nil

    private var isSmall: Bool { family == .systemSmall }

    /// Small- und Medium-Widgets sind gleich hoch (~158pt); nach Abzug von Rand und Kopfzeile
    /// bleiben nur rund fünf Zeilen in voller Größe. Sind es mehr, wird alles gleichmäßig
    /// verkleinert - aber nur bis `minScale`, darunter wäre die Schrift nicht mehr lesbar.
    private static let comfortableRows = 5
    private static let minScale: CGFloat = 0.65
    /// so viele Zeilen passen bei `minScale` gerade noch (Hinweiszeilen mitgezählt)
    private static let maxRows = 8

    /// sichtbarer Ausschnitt des Tages. Passen nicht alle Blöcke, entfallen zuerst bereits
    /// beendete Stunden oben, dann die letzten unten; je eine Hinweiszeile („+N früher“ /
    /// „+N später“) zeigt, dass und wie viele Blöcke fehlen.
    private var window: (lessons: ArraySlice<WidgetLesson>, before: Int, after: Int) {
        let all = plan.lessons
        let n = all.count
        let rows = Self.maxRows
        guard n > rows else { return (all[...], 0, 0) }
        // erster noch nicht beendeter Block (ohne Endzeit zählt er als nicht beendet)
        let firstOpen = all.firstIndex { ($0.end ?? .distantFuture) > now } ?? n
        if firstOpen < rows - 1 {
            // er steht schon in den ersten Zeilen: nur unten kürzen
            return (all[0..<(rows - 1)], 0, n - (rows - 1))
        }
        // oben kürzen; passt der Rest nicht mit einer Hinweiszeile, auch unten
        if n - firstOpen <= rows - 1 {
            let start = n - (rows - 1)
            return (all[start...], start, 0)
        }
        let end = firstOpen + rows - 2
        return (all[firstOpen..<end], firstOpen, n - end)
    }

    private var scale: CGFloat {
        let w = window
        let count = CGFloat(w.lessons.count + (w.before > 0 ? 1 : 0) + (w.after > 0 ? 1 : 0))
        let comfortable = CGFloat(Self.comfortableRows)
        guard count > comfortable else { return 1 }
        return max(Self.minScale, comfortable / count)
    }

    private var padding: CGFloat { isSmall ? 9 : 13 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: isSmall ? 4 : 6) {
                Text(dayLabel ?? "Heute").font(.system(size: isSmall ? 11 : 13, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.8)
                // Wochentagskürzel nur bei "Heute"/"Morgen" (ein voller Wochentagsname trägt es schon)
                if dayLabel == nil || dayLabel == "Morgen" {
                    Text(weekdayAbbrevHome(plan.dateString))
                        .font(.system(size: isSmall ? 10 : 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 2)
                Text(plan.className).font(.system(size: isSmall ? 10 : 11))
                    .foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, 4)   // gleicher horizontaler Rand wie die Stundenzeilen (LessonRow)
            .padding(.bottom, 5 * scale)
            Spacer(minLength: 0)
            let w = window
            VStack(alignment: .leading, spacing: 2 * scale) {
                if w.before > 0 { moreRow("+\(w.before) früher") }
                ForEach(Array(w.lessons.enumerated()), id: \.offset) { _, l in
                    // im schmalen Widget entfällt das Lehrerkürzel - Fach und Raum haben Vorrang
                    LessonRow(lesson: l, now: now, scale: scale, showTeacher: !isSmall)
                }
                if w.after > 0 { moreRow("+\(w.after) später") }
            }
            Spacer(minLength: 0)
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Hinweis auf ausgeblendete Blöcke - so hoch wie eine Stundenzeile, Text in der Stundenspalte
    private func moreRow(_ text: String) -> some View {
        Text(text).font(.system(size: 12 * scale)).foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.vertical, 2 * scale).padding(.horizontal, 4)
    }
}

private struct LessonRow: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let lesson: WidgetLesson
    let now: Date
    /// gemeinsamer Verkleinerungsfaktor, wenn viele Stunden in die Höhe passen müssen
    var scale: CGFloat = 1
    /// im schmalen Widget wird das Lehrerkürzel weggelassen (Fach und Raum haben Vorrang)
    var showTeacher: Bool = true

    private var isCurrent: Bool { lesson.isRunning(at: now) }
    private var subjectText: String { lesson.isFree ? "Frei" : (lesson.isCancelled ? "Ausfall" : lesson.subject) }
    /// bei Freistunde/Ausfall gibt es weder Lehrer noch Raum - die Spalten bleiben dann leer,
    /// damit die übrigen Zeilen trotzdem bündig untereinander stehen
    private var hasDetails: Bool { !lesson.isFree && !lesson.isCancelled }

    // Der Stundenspalte wird etwas mehr gegönnt, weil zusammengefasste Doppelstunden ("4.–5.")
    // in der aktuellen Stunde zusätzlich fett gesetzt werden.
    private var hourWidth: CGFloat { 36 * scale }
    private var subjectWidth: CGFloat { 62 * scale }
    private var roomWidth: CGFloat { 30 * scale }

    private var subjectView: some View {
        changeMarked(Text(subjectText), lesson.isCancelled || lesson.subjectChanged, renderingMode)
            .font(.system(size: 13 * scale, weight: .semibold))
            .foregroundStyle((lesson.isCancelled || lesson.subjectChanged) ? .red : .primary)
            .lineLimit(1).minimumScaleFactor(0.8)
    }

    var body: some View {
        HStack(spacing: 6 * scale) {
            Text(lesson.hourLabel).font(.system(size: 12 * scale, weight: isCurrent ? .bold : .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: hourWidth, alignment: .leading)
            if showTeacher {
                // Das Fach bekommt eine feste Spalte, damit der Rest zwischen Fach und Raum für
                // alle Zeilen gleich breit ist - nur dann steht das zentrierte Lehrerkürzel
                // gleichzeitig mittig und über alle Zeilen bündig untereinander.
                subjectView.frame(width: subjectWidth, alignment: .leading)
                changeMarked(Text(hasDetails ? lesson.teacher : ""), hasDetails && lesson.teacherChanged, renderingMode)
                    .font(.system(size: 12 * scale)).italic()
                    .foregroundStyle(lesson.teacherChanged ? .red : .secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // ohne Lehrerspalte (schmales Widget) darf das Fach den freien Platz nutzen
                subjectView.frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(hasDetails ? lesson.roomText : "").font(.system(size: 12 * scale))
                .foregroundStyle(lesson.roomChanged ? .red : .secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(width: roomWidth, alignment: .trailing)
                // Die Raumspalte ist zu schmal für Symbol und Raum. Das Dreieck steht deshalb links
                // daneben im freien Bereich, so verschieben sich die Spalten nicht.
                .overlay(alignment: .leading) {
                    if hasDetails && lesson.roomChanged && renderingMode != .fullColor {
                        Image(systemName: keplerChangedSymbol)
                            .font(.system(size: 10 * scale))
                            .offset(x: -14 * scale)
                    }
                }
        }
        .padding(.vertical, 2 * scale).padding(.horizontal, 4)
        .background(isCurrent ? keplerBlue.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 5))
    }
}

private struct MessageCard: View {
    let text: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "calendar").font(.system(size: 22)).foregroundStyle(.secondary)
            Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
}

// MARK: - Inhalte je Größe

private struct SmallCurrentView: View {
    let entry: HomeEntry
    var body: some View {
        if let m = entry.message { MessageCard(text: m) }
        else if let plan = entry.plan {
            if let cur = plan.runningLesson(at: entry.date) { LessonCard(lesson: cur, relation: .now, now: entry.date) }
            else if let nx = plan.upcomingLessons(after: entry.date).first { LessonCard(lesson: nx, relation: .next, now: entry.date) }
            else if let first = plan.untimedLessons.first { LessonCard(lesson: first, relation: .today, now: entry.date) }
            else { MessageCard(text: "Kein Unterricht mehr") }
        }
    }
}

private struct SmallNextView: View {
    let entry: HomeEntry
    var body: some View {
        if let m = entry.message { MessageCard(text: m) }
        else if let plan = entry.plan {
            if let nx = plan.upcomingLessons(after: entry.date).first { LessonCard(lesson: nx, relation: .next, now: entry.date) }
            else if let first = plan.untimedLessons.first { LessonCard(lesson: first, relation: .today, now: entry.date) }
            else { MessageCard(text: "Keine weitere Stunde") }
        }
    }
}

private struct MediumCurrentNextView: View {
    let entry: HomeEntry
    var body: some View {
        if let m = entry.message { MessageCard(text: m) }
        else if let plan = entry.plan {
            let cur = plan.runningLesson(at: entry.date)
            let up = plan.upcomingLessons(after: entry.date)
            HStack(spacing: 0) {
                if let cur = cur {
                    LessonCard(lesson: cur, relation: .now, now: entry.date)
                    Divider()
                    if let nx = up.first { LessonCard(lesson: nx, relation: .next, now: entry.date) }
                    else { MessageCard(text: "Danach Schluss") }
                } else if let nx = up.first {
                    LessonCard(lesson: nx, relation: .next, now: entry.date)
                    Divider()
                    if up.count > 1 { LessonCard(lesson: up[1], relation: .later, now: entry.date) }
                    else { MessageCard(text: "Danach Schluss") }
                } else if !plan.untimedLessons.isEmpty {
                    let ul = plan.untimedLessons
                    LessonCard(lesson: ul[0], relation: .today, now: entry.date)
                    if ul.count > 1 { Divider(); LessonCard(lesson: ul[1], relation: .today, now: entry.date) }
                } else { MessageCard(text: "Kein Unterricht mehr") }
            }
        }
    }
}

private struct MediumNextLaterView: View {
    let entry: HomeEntry
    var body: some View {
        if let m = entry.message { MessageCard(text: m) }
        else if let plan = entry.plan {
            let up = plan.upcomingLessons(after: entry.date)
            HStack(spacing: 0) {
                if let nx = up.first {
                    LessonCard(lesson: nx, relation: .next, now: entry.date)
                    Divider()
                    if up.count > 1 { LessonCard(lesson: up[1], relation: .later, now: entry.date) }
                    else { MessageCard(text: "Danach Schluss") }
                } else if !plan.untimedLessons.isEmpty {
                    let ul = plan.untimedLessons
                    LessonCard(lesson: ul[0], relation: .today, now: entry.date)
                    if ul.count > 1 { Divider(); LessonCard(lesson: ul[1], relation: .today, now: entry.date) }
                } else { MessageCard(text: "Keine weitere Stunde") }
            }
        }
    }
}

private struct DayView: View {
    let entry: HomeEntry
    var body: some View {
        if let m = entry.message { MessageCard(text: m) }
        else if let plan = entry.plan { DayList(plan: plan, now: entry.date, dayLabel: entry.dayLabel) }
        // kann nach resolveHomeState nicht eintreten - ohne diesen Zweig wäre die View aber leer,
        // und ein Widget ohne Inhalt zeigt nur einen leeren Rahmen
        else { MessageCard(text: "Bitte App öffnen") }
    }
}

// MARK: - Provider

struct HomeEntry: TimelineEntry {
    let date: Date
    let plan: PlanData?
    let message: String?
    var dayLabel: String? = nil   // "Morgen"/"Montag"… wenn der nächste Schultag gezeigt wird
    var nextDay: Bool = false      // true = ganzer Plan des nächsten Schultags (siehe resolveHomeState)
}

// MARK: - Zustand: heute (bis Schulschluss) vs. ganzer Plan des nächsten Schultags

private enum HomeMode { case today, nextDay }

/// wann ein Widget vom heutigen auf den morgigen Plan umschaltet:
/// - `schoolEnd`: erst nach Ende der letzten Stunde (Aktuelle Stunde, Tagesplan)
/// - `noMoreUpcoming`: schon sobald keine weitere Stunde mehr ansteht, d.h. während der letzten
///   Stunde (Nächste Stunde – dort wäre sonst nur „keine weitere Stunde")
private enum RolloverTrigger { case schoolEnd, noMoreUpcoming }

/// zentrale Logik für ALLE Homescreen-Widgets: bis zum Umschaltpunkt (siehe `rollover`) den heutigen
/// Plan; danach – sowie am Wochenende / an freien Tagen – den ganzen Plan des nächsten Schultags.
/// - `mode`: today = aktuelle/nächste Stunde bzw. heutiger Tagesplan; nextDay = ganzer Plan von morgen
/// - `dayLabel`: nil bei heute, sonst "Morgen"/Wochentag
/// - `store`: liefert die Pläne; eine Timeline reicht für alle Einträge denselben Store durch, damit
///   die Daten nur einmal gelesen und geparst werden
private func resolveHomeState(now: Date, rollover: RolloverTrigger = .schoolEnd, store: PlanStore)
    -> (mode: HomeMode, plan: PlanData?, dayLabel: String?, message: String?) {
    let weekend = keplerIsWeekend(now)

    // heutigen Plan ermitteln (nur Wochentags); data_next abfangen, falls es inzwischen "heute" ist
    let todayPlan = weekend ? nil : store.todayPlan(at: now)

    // heute noch relevant? (Schultag, Plan vorhanden, vor dem Umschaltpunkt)
    if let plan = todayPlan, !plan.holiday, !plan.lessons.isEmpty {
        // schoolEnd: Ende der letzten Stunde; noMoreUpcoming: Beginn der letzten Stunde
        // (ab dann steht keine weitere Stunde mehr an)
        let threshold = (rollover == .schoolEnd)
            ? plan.lessons.compactMap { $0.end }.max()
            : plan.lessons.compactMap { $0.start }.max()
        if threshold == nil || now < threshold! {
            return (.today, plan, nil, nil)
        }
        // sonst: Umschaltpunkt erreicht -> nächster Schultag
    }

    // Plan für heute vorhanden, aber ohne Stunden (z.B. alle Kurse ausgeblendet oder unvollständige
    // Daten): Das ist ein Problem des HEUTIGEN Plans - nicht auf morgen weiterrollen, sonst stünde
    // dort "Morgen: kein Plan", obwohl der heutige Plan gemeint ist. Freie Tage sind ausgenommen,
    // dort ist der Blick auf den nächsten Schultag gewollt.
    if let plan = todayPlan, !plan.holiday, plan.lessons.isEmpty {
        return (.today, nil, nil, "Kein Plan")
    }

    // nächster Schultag (nach Schulschluss, am Wochenende, an freien Tagen oder ohne heutige Daten)
    let next = store.nextSchoolDay(after: now)
    let label = next.label
    guard let plan = next.plan else {
        // kein Plan für morgen vorhanden: an einem Wochentag ohne heutige Daten eher "App öffnen"
        if todayPlan == nil && !weekend {
            return (.today, nil, nil, "Bitte App öffnen")
        }
        return (.nextDay, nil, label, "\(label): noch kein Plan")
    }
    // "frei" nur bei einem echten freien Tag (lokal aus dem Ferienkalender bestimmt, unabhängig von
    // der API). Ein Plan ohne Stunden kann dagegen auch von fehlenden Daten kommen - das darf nicht
    // als unterrichtsfrei ausgegeben werden.
    if plan.holiday { return (.nextDay, nil, label, "\(label): frei") }
    if plan.lessons.isEmpty { return (.nextDay, nil, label, "\(label): kein Plan") }
    return (.nextDay, plan, label, nil)
}

/// gemeinsamer Provider für alle Homescreen-Widgets. Sie unterscheiden sich nur in der Darstellung
/// des `today`-Modus (aktuelle/nächste Stunde bzw. heutiger Tagesplan); im `nextDay`-Modus zeigen
/// alle den ganzen Plan des nächsten Schultags.
struct HomeProvider: AppIntentTimelineProvider {
    fileprivate var rollover: RolloverTrigger = .schoolEnd

    func placeholder(in context: Context) -> HomeEntry {
        HomeEntry(date: Date(), plan: nil, message: "Stundenplan")
    }
    func snapshot(for configuration: PlanSelectionIntent, in context: Context) async -> HomeEntry {
        makeEntry(at: Date(), planName: configuration.plan?.id)
    }
    func timeline(for configuration: PlanSelectionIntent, in context: Context) async -> Timeline<HomeEntry> {
        let now = Date()
        return Timeline(entries: timelineEntries(now: now, planName: configuration.plan?.id),
                        policy: .after(keplerNextReload(after: now)))
    }

    /// alle Einträge einer Timeline ab `now`. Die Pläne werden dafür nur einmal geladen (ein
    /// gemeinsamer PlanStore für alle Einträge).
    func timelineEntries(now: Date, planName: String?) -> [HomeEntry] {
        let store = PlanStore(planName: planName)
        // heutigen Plan wie in resolveHomeState wählen: "data", sonst "data_next" falls es inzwischen
        // heute ist (z.B. früh, bevor die App lief) - sonst stünde die Timeline auf einem Eintrag still
        let todayPlan = keplerIsWeekend(now) ? nil : store.todayPlan(at: now)

        // kritische Einträge (IMMER behalten): jetzt + alle Stunden-Grenzen + Schulschluss-Umschaltpunkt
        // + Mitternacht. Sie liefern die Rollover-Flips für beide Modi (Schulschluss bzw. Beginn der
        // letzten Stunde) und den Tageswechsel - der Eintrag um Mitternacht überbrückt die Zeit bis
        // zum Neuladen kurz danach (keplerNextReload). Sie dürfen daher NIE durch eine Obergrenze
        // abgeschnitten werden.
        var critical = Set<Date>([now, keplerNextMidnight(after: now)])
        var ticks: [Date] = []   // reine Fortschritts-Ticks - dürfen gedeckelt werden
        if let today = todayPlan, !today.holiday, !today.lessons.isEmpty {
            for l in today.lessons {
                if let s = l.start, s > now { critical.insert(s) }
                if let e = l.end, e > now { critical.insert(e) }
            }
            if let lastEnd = today.lessons.compactMap({ $0.end }).max(), lastEnd > now {
                critical.insert(lastEnd); critical.insert(lastEnd.addingTimeInterval(1))
                // 5-Minuten-Takt für den Fortschrittsbalken, erst ab Schulbeginn bis Schulschluss
                let firstStart = today.lessons.compactMap { $0.start }.min() ?? now
                var t = max(now, firstStart)
                while t < lastEnd { ticks.append(t); t = t.addingTimeInterval(300) }
            }
        }
        // kritische Einträge zuerst; Ticks füllen nur das Restbudget (früheste zuerst), damit die
        // Timeline höchstens 150 Einträge hat
        var dates = critical
        let budget = max(0, 150 - critical.count)
        for t in ticks.sorted().prefix(budget) { dates.insert(t) }

        // `now` ist immer enthalten, die Liste also nie leer
        return dates.filter { $0 >= now }.sorted().map { makeEntry(at: $0, planName: planName, store: store) }
    }

    /// Eintrag für einen Zeitpunkt. Ohne `store` werden die Pläne frisch gelesen (Snapshot).
    private func makeEntry(at date: Date, planName: String?, store: PlanStore? = nil) -> HomeEntry {
        let (mode, plan, dayLabel, message) = resolveHomeState(
            now: date, rollover: rollover, store: store ?? PlanStore(planName: planName))
        return HomeEntry(date: date, plan: plan, message: message, dayLabel: dayLabel, nextDay: mode == .nextDay)
    }
}

// MARK: - Widgets

struct KeplerCurrentWidget: Widget {
    let kind = "KeplerCurrentWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PlanSelectionIntent.self,
                               provider: HomeProvider()) { entry in
            CurrentDispatch(entry: entry).widgetBackground(.widgetBg)
        }
        .configurationDisplayName("Aktuelle Stunde")
        .description("Zeigt die aktuelle (und nächste) Stunde deines Plans.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
private struct CurrentDispatch: View {
    @Environment(\.widgetFamily) private var family
    let entry: HomeEntry
    var body: some View {
        if entry.nextDay {
            DayView(entry: entry)   // nach Schulschluss: ganzer Plan des nächsten Tages
        } else if family == .systemMedium {
            MediumCurrentNextView(entry: entry)
        } else {
            SmallCurrentView(entry: entry)
        }
    }
}

struct KeplerNextWidget: Widget {
    let kind = "KeplerNextWidget"
    var body: some WidgetConfiguration {
        // Rollover schon während der letzten Stunde (dann steht keine weitere Stunde mehr an)
        AppIntentConfiguration(kind: kind, intent: PlanSelectionIntent.self,
                               provider: HomeProvider(rollover: .noMoreUpcoming)) { entry in
            NextDispatch(entry: entry).widgetBackground(.widgetBg)
        }
        .configurationDisplayName("Nächste Stunde")
        .description("Zeigt die nächste anstehende Stunde deines Plans.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
private struct NextDispatch: View {
    @Environment(\.widgetFamily) private var family
    let entry: HomeEntry
    var body: some View {
        if entry.nextDay {
            DayView(entry: entry)   // ab Beginn der letzten Stunde: ganzer Plan des nächsten Tages
        } else if family == .systemMedium {
            MediumNextLaterView(entry: entry)
        } else {
            SmallNextView(entry: entry)
        }
    }
}

struct KeplerDayWidget: Widget {
    let kind = "KeplerDayWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PlanSelectionIntent.self,
                               provider: HomeProvider()) { entry in
            DayView(entry: entry).widgetBackground(.widgetBg)
        }
        .configurationDisplayName("Tagesplan")
        .description("Zeigt den Stundenplan deiner Klasse – nach Schulschluss und am Wochenende schon den nächsten Schultag.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
