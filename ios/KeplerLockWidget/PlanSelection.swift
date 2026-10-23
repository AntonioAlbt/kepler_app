// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2026 Jakob Krause
//
// This file is part of kepler_app. It is licensed under the GNU GPLv3.
// See the LICENSE file in the repository root for details.
//
// Widget-Konfiguration: erlaubt es, beim Bearbeiten eines Widgets auszuwählen, welcher der in der
// App ausgewählten Pläne (Klasse bzw. Lehrer) angezeigt wird. Die Flutter-App schreibt bereits alle
// Pläne in die App-Group (siehe lib/libs/plan_widgets.dart); hier werden sie nur als
// auswählbare Einträge angeboten.

import AppIntents
import WidgetKit

// MARK: - Verfügbare Pläne

/// Namen aller aktuell geteilten Pläne für die Auswahl beim Bearbeiten des Widgets
/// (siehe keplerPlanNames in KeplerLockWidget.swift).
func availablePlanNames() -> [String] { keplerPlanNames() }

// MARK: - AppEntity

/// ein auswählbarer Plan. Als `id` dient der Planname (z.B. "9c" oder das Lehrerkürzel) – nicht der
/// Index: so bleibt die Auswahl gültig, wenn in der App Pläne hinzugefügt, entfernt oder umsortiert
/// werden.
struct PlanEntity: AppEntity {
    let id: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Plan" }
    static var defaultQuery = PlanQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

struct PlanQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PlanEntity] {
        let available = availablePlanNames()
        return identifiers.filter { available.contains($0) }.map { PlanEntity(id: $0) }
    }

    func suggestedEntities() async throws -> [PlanEntity] {
        availablePlanNames().map { PlanEntity(id: $0) }
    }

    /// Vorauswahl beim Hinzufügen eines Widgets: der primär ausgewählte Plan. Gibt es nur einen
    /// Plan, ist das automatisch dieser.
    func defaultResult() async -> PlanEntity? {
        availablePlanNames().first.map { PlanEntity(id: $0) }
    }
}

// MARK: - Intent

/// Konfiguration aller Kepler-Widgets. Ist kein Plan gesetzt (z.B. bei Widgets, die noch aus einer
/// älteren App-Version stammen), verwenden die Provider den primären Plan.
struct PlanSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Plan auswählen" }
    static var description: IntentDescription {
        IntentDescription("Wähle, welcher deiner Pläne in diesem Widget angezeigt wird.")
    }

    @Parameter(title: "Plan")
    var plan: PlanEntity?

    init() {}

    init(plan: PlanEntity?) {
        self.plan = plan
    }
}
