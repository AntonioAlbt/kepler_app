// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2026 Jakob Krause
//
// This file is part of kepler_app. It is licensed under the GNU GPLv3.
// See the LICENSE file in the repository root for details.
//
// Der Bildschirm der Watch-App: der Tagesplan, ganz links die Planauswahl. Ziel jedes
// Complication-Tipps.
// Datenmodell, Parsing und Blockbildung kommen unveraendert aus KeplerLockWidget.swift.

import SwiftUI
import WidgetKit

/// Ein blaetterbarer Tag. Die App-Group enthaelt hoechstens zwei: "data" (heute) und
/// "data_next" (naechster Schultag) - mehr uebertraegt das iPhone nicht.
private struct DayOption: Identifiable {
    let id: String          // Datum als Schluessel, stabil ueber Neuberechnungen
    let label: String       // "Heute", "Morgen", Wochentagsname
    let plan: PlanData?
    let message: String?    // gesetzt, wenn fuer diesen Tag nichts anzuzeigen ist
}

/// Sammelt alle Tage, zu denen Daten vorliegen - in zeitlicher Reihenfolge.
/// Leer ist die Liste nie: Gibt es gar nichts, steht ein Hinweis-Tag darin, damit
/// die Ansicht nicht leer bleibt.
/// Die Auswahl der Tage entspricht den Widgets (PlanStore.todayPlan / nextSchoolDay); gezeigt wird
/// `planName`, ohne Angabe oder wenn es den Plan nicht mehr gibt der primaere (plans[0]).
private func availableDays(now: Date, planName: String?) -> [DayOption] {
    let store = PlanStore(planName: planName)
    var days: [DayOption] = []

    /// Hinweis statt Stundenliste, wenn der Tag frei ist oder keine Stunden hat
    func option(id: String, label: String, plan: PlanData) -> DayOption {
        if plan.holiday { return DayOption(id: id, label: label, plan: nil, message: "frei") }
        if plan.lessons.isEmpty { return DayOption(id: id, label: label, plan: nil, message: "Kein Plan") }
        return DayOption(id: id, label: label, plan: plan, message: nil)
    }

    // --- heute (nur an Schultagen) ---
    if !keplerIsWeekend(now), let plan = store.todayPlan(at: now) {
        days.append(option(id: store.dateFormatter.string(from: now), label: "Heute", plan: plan))
    }

    // --- naechster Schultag ---
    let next = store.nextSchoolDay(after: now)
    if let plan = next.plan {
        days.append(option(id: store.dateFormatter.string(from: next.date), label: next.label, plan: plan))
    }

    if days.isEmpty {
        days.append(DayOption(id: "leer", label: next.label, plan: nil, message: keplerOpenAppHint))
    }
    return days
}

/// Welcher Tag beim Oeffnen zuerst gezeigt wird: heute, solange der Schultag laeuft,
/// danach der naechste. Wer nachmittags auf die Complication tippt, will schon morgen sehen.
private func initialDayID(days: [DayOption], now: Date) -> String {
    if let first = days.first, first.label == "Heute", let plan = first.plan {
        let end = plan.lessons.compactMap { $0.end }.max()
        if end == nil || now < end! { return first.id }
        // Schultag vorbei -> naechsten Tag zeigen, falls vorhanden
        return days.count > 1 ? days[1].id : first.id
    }
    return days.first?.id ?? "leer"
}

struct DayPlanScreen: View {
    @EnvironmentObject private var sync: WatchSync
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()
    /// nil = der Nutzer hat noch nicht geblaettert; dann gilt der automatisch bestimmte Tag.
    /// Bewusst optional statt mit einem Startwert, der erst in onAppear gesetzt wuerde: sonst
    /// rendert TabView einmal mit einem ungueltigen Tag - sichtbar als kurz falscher Tagestitel.
    @State private var selection: String?
    /// in der Uhr gewaehlter Plan ("" = primaerer Plan). Liegt in der App-Group, damit die
    /// Complications ihn ebenfalls lesen (keplerWatchSelectedPlan).
    @AppStorage(watchPlanKey, store: UserDefaults(suiteName: appGroupId)) private var watchPlan = ""

    /// Tag der Planauswahl-Seite in der TabView
    private static let planPageID = "plan"

    private var planNames: [String] { keplerPlanNames() }
    /// der tatsaechlich gezeigte Plan: der gewaehlte, falls es ihn noch gibt, sonst der primaere
    private var shownPlan: String? {
        planNames.contains(watchPlan) ? watchPlan : planNames.first
    }
    private var days: [DayOption] { availableDays(now: now, planName: shownPlan) }

    private var shownDay: Binding<String> {
        Binding(
            get: { selection ?? initialDayID(days: days, now: now) },
            set: { selection = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            // Seitenweises Blaettern zwischen den vorliegenden Tagen. Bei nur einem Tag
            // zeigt watchOS keine Punktreihe an - die Ansicht wirkt dann wie eine einfache Liste.
            TabView(selection: shownDay) {
                // ganz links: Planauswahl, nur wenn es etwas zu waehlen gibt
                if planNames.count > 1 {
                    PlanPickerPage(names: planNames, selected: shownPlan) { name in
                        // der primaere Plan wird als "" gespeichert, damit die Uhr ihm folgt,
                        // wenn sich die Reihenfolge der Plaene in der App aendert
                        watchPlan = (name == planNames.first) ? "" : name
                        WidgetCenter.shared.reloadAllTimelines()
                        selection = nil   // zurueck zum automatisch bestimmten Tag
                    }
                    .tag(Self.planPageID)
                }
                ForEach(days) { day in
                    DayPage(day: day, now: now)
                        .tag(day.id)
                }
            }
            .tabViewStyle(.page)
            .navigationTitle(currentLabel)
            .navigationBarTitleDisplayMode(.inline)
        }

        // beim Zurueckkehren in den Vordergrund neu bewerten - sonst zeigt die Ansicht den Stand
        // vom letzten Oeffnen, was ausgerechnet ueber Mittag falsch waere.
        // Einparametrige onChange-Form: die zweiparametrige gibt es erst ab watchOS 10.
        .onChange(of: scenePhase) { phase in
            // Beim Zurueckkehren wieder den relevanten Tag zeigen: Wer die App mittags erneut
            // oeffnet, will nicht auf der Seite stehen, die er gestern Abend angeschaut hat.
            if phase == .active { now = Date(); selection = nil }
        }
        // eingehende Daten vom iPhone: Ansicht neu berechnen, aber die Auswahl des Nutzers
        // NICHT ueberschreiben - sonst springt die Seite unter dem Finger weg
        .onChange(of: sync.revision) { _ in
            now = Date()
            if let sel = selection, sel != Self.planPageID, !days.contains(where: { $0.id == sel }) {
                selection = nil
            }
        }
    }

    private var currentLabel: String {
        let id = shownDay.wrappedValue
        if id == Self.planPageID { return "Plan" }
        return days.first { $0.id == id }?.label ?? ""
    }
}

/// Planauswahl: alle Plaene aus der App, der gezeigte mit Haken. Antippen waehlt ihn.
private struct PlanPickerPage: View {
    let names: [String]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        List(names, id: \.self) { name in
            Button { onSelect(name) } label: {
                HStack {
                    Text(name).font(.system(size: 17, weight: .semibold))
                    Spacer(minLength: 0)
                    if name == selected { Image(systemName: "checkmark").foregroundStyle(keplerBlue) }
                }
            }
        }
    }
}

/// Eine Tagesseite - entweder die Stundenliste oder ein Hinweis.
private struct DayPage: View {
    let day: DayOption
    let now: Date

    var body: some View {
        if let plan = day.plan {
            LessonList(plan: plan, now: now)
        } else {
            EmptyState(text: day.message ?? keplerOpenAppHint)
        }
    }
}

/// Stundenliste. List statt ScrollView+VStack: liefert Digital-Crown-Rasterung pro Zeile
/// und das richtige Randverhalten, ohne dass man beides nachbauen muss.
///
/// Zeilen-ID ist die Position in `plan.lessons`, nicht die Stundennummer: Parallele Kurse (z.B. LA
/// und FR jeweils in der 2.–3. Stunde) bleiben getrennte Bloecke mit gleicher schoolHour, und
/// doppelte IDs bringen ForEach und scrollTo durcheinander.
private struct LessonList: View {
    let plan: PlanData
    let now: Date

    /// Positionen aller gerade laufenden Bloecke - bei parallelen Kursen mehrere
    private var currentIndices: Set<Int> {
        Set(plan.lessons.indices.filter { plan.lessons[$0].isRunning(at: now) })
    }

    var body: some View {
        let current = currentIndices
        ScrollViewReader { proxy in
            List {
                Section {
                    ForEach(Array(plan.lessons.enumerated()), id: \.offset) { index, lesson in
                        WatchLessonRow(lesson: lesson, isCurrent: current.contains(index))
                            .id(index)
                    }
                } header: {
                    Text(plan.className).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .listStyle(.carousel)
            .onAppear {
                // Der Punkt, der ueber die Brauchbarkeit entscheidet: Wer mittags auf die
                // Complication tippt, will die laufende Stunde sehen - nicht die erste des Tages.
                // bei parallelen Kursen auf den ersten laufenden Block
                guard let target = current.min() else { return }
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }
}

private struct WatchLessonRow: View {
    let lesson: WidgetLesson
    let isCurrent: Bool

    private var subject: String {
        lesson.isFree ? "Frei" : (lesson.isCancelled ? "Ausfall" : lesson.subject)
    }
    private var timeText: String {
        guard let s = lesson.start, let e = lesson.end else { return "" }
        return "\(keplerTimeString(s)) – \(keplerTimeString(e))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(lesson.hourLabel)
                    .font(.system(size: 13, weight: isCurrent ? .bold : .regular))
                    .foregroundStyle(.secondary)
                Text(subject)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(lesson.isCancelled || lesson.subjectChanged ? .red : .primary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            if !lesson.isFree && !lesson.isCancelled {
                HStack(spacing: 6) {
                    if !lesson.roomText.isEmpty {
                        Text(lesson.roomText)
                            .foregroundStyle(lesson.roomChanged ? .red : .secondary)
                    }
                    if !lesson.teacher.isEmpty {
                        Text(lesson.teacher).italic()
                            .foregroundStyle(lesson.teacherChanged ? .red : .secondary)
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13))
                .lineLimit(1).minimumScaleFactor(0.8)
            } else if !lesson.info.isEmpty {
                Text(lesson.info).font(.system(size: 12))
                    .foregroundStyle(.secondary).lineLimit(2)
            }
            if !timeText.isEmpty {
                Text(timeText).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(
            isCurrent
                ? RoundedRectangle(cornerRadius: 10).fill(keplerBlue.opacity(0.28))
                : RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.14))
        )
    }
}

private struct EmptyState: View {
    let text: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 24)).foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 15)).multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
