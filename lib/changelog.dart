import 'package:flutter/material.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:provider/provider.dart';

/// Changelog-Eintrag
class CLEntry {
  /// Titel des Eintrags
  final String title;
  /// Beschreibung, optional
  final String? description;
  /// dynamischer Generator für Beschreibung, damit sie auf Anrede angepasst werden kann
  final String Function(bool sie)? descGen;

  const CLEntry({required this.title, this.description, this.descGen});

  /// erzeugt ein entsprechendes ListTile aus den Daten
  ListTile generateTile(bool sie) => ListTile(
    title: Text(title),
    subtitle: descGen != null ? Text(descGen!(sie)) : description != null ? Text(description!) : null,
  );
}

/// Liste aller Änderungen seit Einführung changelog.dart
/// Hinweis: möglichst nach größeren Änderungen aktualisieren! (nicht vergessen, wie ich für 62)
/// Aber nur große Änderungen und möglichst kurz zusammenfassen, sonst liest sich das wirklich niemand mehr durch.
final versionChanges = {
  58: CLEntry(
    title: "Farbanimationen hinzugefügt",
    descGen: (sie) => "${sie ? "Sie können" : "Du kannst"} jetzt in den Einstellungen (Kategorie \"Lustiges\") den Regenbogen-Modus der App aktivieren. Dabei werden verschiedene Oberflächen der App mit einer Regenbogen-Farbanimation versehen.",
  ),
  59: const CLEntry(
    title: "Klausurenanzeige hinzugefügt",
    description: "In der persönlichen Stundenplanansicht werden jetzt für Schüler in Jahrgang 11 und 12 automatisch eingetragene Klausuren angezeigt. Dies kann in den Einstellungen angepasst werden.",
  ),
  60: const CLEntry(
    title: "Letzte Raumverwendungen markiert",
    description: "In Stundenplanansichten wird die letze Verwendung eines Raumes an einem Tag mit einem neuen Icon hervorgehoben.",
  ),
  62: const CLEntry(
    title: "Neue Funktionen für LernSax-E-Mails",
    description: "Mit der Kepler-App können jetzt neue LernSax-E-Mails verschickt und vorhandene z.B. weitergeleitet oder gelöscht werden.",
  ),
  66: const CLEntry(
    title: "Mehrere Benutzer jetzt unterstützt",
    description: "Zum persönlichen Stundenplan können jetzt mehrere Klassen hinzugefügt werden. Auch mehrere LernSax-Konten werden jetzt unterstützt.",
  ),
  72: CLEntry(
    title: "Navigationsenträge ausblendbar",
    descGen: (sie) => "${sie ? "Sie können" : "Du kannst"} jetzt in den Einstellungen für bessere Übersichtlichkeit Einträge in der Seitenleiste ausblenden.",
  ),
  73: CLEntry(
    title: "Einstellungen übertragbar",
    descGen: (sie) => "${sie ? "Sie können jetzt Ihre" : "Du kannst jetzt deine"} Einstellungen auf ein anderes Gerät übertragen.",
  ),
  76: CLEntry(
    title: "Eigene Ereignisse erstellen",
    descGen: (sie) => "${sie ? "Sie können" : "Du kannst"} jetzt eigene Ereignisse im Stundenplan erstellen, und auch dafür benachrichtigt werden.",
  ),
};

/// ermittelt alle anzuzeigenden Änderungseinträge mit den zwei gegebenen Versionen
List<CLEntry> computeChangelog(int currentVersion, int lastVersion) {
  List<CLEntry> changelog = [];

  for (int version = lastVersion + 1; version <= currentVersion; version++) {
    if (versionChanges.containsKey(version)) {
      changelog.add(versionChanges[version]!);
    }
  }

  return changelog;
}

/// erstellt den Änderungsdialog
Widget? getChangelogDialog(int currentVersion, int lastVersion, BuildContext ctx) {
  final cl = computeChangelog(currentVersion, lastVersion);
  if (cl.isEmpty) return null;

  final sie = Provider.of<Preferences>(ctx, listen: false).preferredPronoun == Pronoun.sie;

  return AlertDialog(
    title: const Text("Neue Funktionen!"),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...computeChangelog(currentVersion, lastVersion).map((e) => e.generateTile(sie)),
          const Text("Diese Info wird nur einmal angezeigt."),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Ok, schließen")),
    ],
  );
}
