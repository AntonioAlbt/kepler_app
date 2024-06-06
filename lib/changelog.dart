import 'package:flutter/material.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/main.dart';
import 'package:provider/provider.dart';

class CLEntry {
  final String title;
  final String? description;
  final String Function(bool sie)? descGen;

  const CLEntry({required this.title, this.description, this.descGen});

  ListTile generateTile(bool sie) => ListTile(
    title: Text(title),
    subtitle: descGen != null ? Text(descGen!(sie)) : description != null ? Text(description!) : null,
  );
}

final versionChanges = {
  //// wrote this whole system for this, but then decided that some parents/students might overreact when seeing this (specifically this "🏳️‍🌈") >:(
  //// even though itd be fitting in june
  // 58: CLEntry(
  //   title: "🏳️‍🌈 Regenbogen-Modus hinzugefügt",
  //   descGen: (sie) => "${sie ? "Sie können" : "Du kannst"} jetzt in den Einstellungen den Regenbogen-Modus der App aktivieren. Dabei werden verschiedene Farben der App zu Regenbogenfarben geändert.",
  // ),
};

List<CLEntry> computeChangelog(int currentVersion, int lastVersion) {
  List<CLEntry> changelog = [];

  for (int version = lastVersion + 1; version <= currentVersion; version++) {
    if (versionChanges.containsKey(version)) {
      changelog.add(versionChanges[version]!);
    }
  }

  return changelog;
}

Widget? getChangelogDialog(int currentVersion, int lastVersion, BuildContext ctx) {
  final cl = computeChangelog(currentVersion, lastVersion);
  if (cl.isEmpty) return null;

  final sie = Provider.of<Preferences>(globalScaffoldContext, listen: false).preferredPronoun == Pronoun.sie;

  return AlertDialog(
    title: const Text("Neue Funktionen!"),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Diese Info wird nur einmal angezeigt."),
          ...computeChangelog(currentVersion, lastVersion).map((e) => e.generateTile(sie)),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Ok, schließen")),
    ],
  );
}
