// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2023-2024 Antonio Albert

// This file is part of kepler_app.

// kepler_app is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// kepler_app is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with kepler_app.  If not, see <http://www.gnu.org/licenses/>.

// Diese Datei ist Teil von kepler_app.

// kepler_app ist Freie Software: Sie können es unter den Bedingungen
// der GNU General Public License, wie von der Free Software Foundation,
// Version 3 der Lizenz oder (nach Ihrer Wahl) jeder neueren
// veröffentlichten Version, weiter verteilen und/oder modifizieren.

// kepler_app wird in der Hoffnung, dass es nützlich sein wird, aber
// OHNE JEDE GEWÄHRLEISTUNG, bereitgestellt; sogar ohne die implizite
// Gewährleistung der MARKTFÄHIGKEIT oder EIGNUNG FÜR EINEN BESTIMMTEN ZWECK.
// Siehe die GNU General Public License für weitere Details.

// Sie sollten eine Kopie der GNU General Public License zusammen mit
// kepler_app erhalten haben. Wenn nicht, siehe <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:kepler_app/main.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:kepler_app/rainbow.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';
import 'package:kepler_app/libs/preferences.dart';

/// all of this is subject to change because of building "updates"
/// - maaaybe the building updates will still take a good while
/// 
/// die Räume sind hardcoded, da der Raumplan und die Übersicht der freien Räume viel zuverlässiger sind,
/// und die Räume so auch kategorisiert werden können
/// -> die App könnte ja sonst nur vom Stundenplan rausfinden, welche Räume es gibt, d.h. wenn ein Raum an
///   einem Tag nicht verwendet wird, weiß die App nicht über die Existenz des Raumes
final allKeplerRooms = [
  "K08", "K10",
  ...rooms("0", 4, 12, [5, 7]),
  ...rooms("1", 8, 15, [12, 14]),
  ...rooms("2", 1, 16, [6, 7, 12, 14]),
  ...rooms("3", 1, 17, [3, 7, 14, 16]),
  "TH", "Jb1", "Jb2",
];
/// Varianten für Räume, Einteilung für Benutzer
enum RoomType {
  /// unassigned sollte eigentlich none heißen;
  /// die alphabetische Reihenfolge ist aber wichtig, damit dieser Typ zuletzt angezeigt wird
  compSci, technic, sports, specialist, music, art, unassigned;
  @override
  String toString() => {
    RoomType.art: "Kunstzimmer",
    RoomType.compSci: "Informatikkabinette",
    RoomType.music: "Musikzimmer",
    RoomType.specialist: "Fachräume",
    RoomType.sports: "Sporthallen",
    RoomType.technic: "TC-Räume",
    RoomType.unassigned: "Allgemein",
  }[this]!;
  String toIdString() => {
    RoomType.art: "art",
    RoomType.compSci: "compSci",
    RoomType.music: "music",
    RoomType.specialist: "specialist",
    RoomType.sports: "sports",
    RoomType.technic: "technic",
    RoomType.unassigned: "unassigned",
  }[this]!;
}
String fromIdStringToString(String idString) => {
  "art": "Kunstzimmer",
  "compSci": "Informatikkabinette",
  "music": "Musikzimmer",
  "specialist": "Fachräume",
  "sports": "Sporthallen",
  "technic": "TC-Räume",
  "unassigned": "Allgemeine Räume",
}[idString] ?? "Unbekannter Raumtyp"; // dieser Fall sollte nie eintreten
// this even more
/// Generierung einer Liste der Raumtyp-IDs als Strings
List<String> listOfRoomTypeIdStrings() {
  final rtlist = RoomType.values.toList();
  List<String> result = [];
  for (var roomtype in rtlist) {
    result.add(roomtype.toIdString());
  }
  return result;
}
/// Zuteilung Räume zu Raumtyp
final specialRoomInfo = {
  RoomType.compSci: ["K08", "K10", "202"],
  RoomType.technic: ["004", "006"],
  RoomType.sports: ["TH", "Jb1", "Jb2"],
  RoomType.specialist: ["113", "115", "213", "215", "313", "315"],
  RoomType.music: ["317"],
  RoomType.art: ["302"],
};
/// Generierung einer Map Raumnummer -> Raumtyp
final specialRoomMap = (){
  final map = <String, RoomType>{};
  specialRoomInfo.forEach((key, value) {
    for (var room in value) {
      map[room] = key;
    }
  });
  return map;
}();

final freeRoomDisplayKey = GlobalKey<StuPlanDisplayState>();

/// generiert Liste von Raumnummern, einschließlich start und end ausschließlich Räume in excludes
List<String> rooms(String prefix, int start, int end, List<int> excludes) {
  final rooms = <String>[];
  for (var i = start; i <= end; i++) {
    if (excludes.contains(i)) continue;
    rooms.add("$prefix${i.toString().padLeft(2, "0")}");
  }
  return rooms;
}

/// prüft, ob ein bestimmter Raumtyp dem Filter entspricht
bool matchesRoomTypeFilter(String roomtype, BuildContext context) {
  final prefs = Provider.of<Preferences>(context, listen: false);
  return prefs.filteredRoomTypes.contains(roomtype);
}

/// zeigt freie Räume für ausgewählten Tag und je nach Stunde kategorisiert nach RoomType an
class FreeRoomsPage extends StatelessWidget {
  const FreeRoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RainbowWrapper(builder: (_, color) => Container(color: color?.withValues(alpha: .5))),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: StuPlanDisplay(
            key: freeRoomDisplayKey,
            mode: SPDisplayMode.freeRooms,
            selected: '',
          ),
        ),
      ],
    );
  }
}

void freeRoomRefreshAction() {
  freeRoomDisplayKey.currentState?.forceRefreshData();
}

void setRoomTypeFilterAction() {
  showDialog(context: globalScaffoldContext, builder: (ctx) => SetRoomTypeFilterDialog());
}

/// Dialog mit Details zur Stunde - Kategorisierung freie Räume mit Text statt Icon
Widget generateFreeRoomsClickDialog(BuildContext context, List<MapEntry<RoomType, List<String>>> freeRoomsList, int hour) {
  return AlertDialog(
    title: Text("Freie Räume in Stunde $hour"),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: freeRoomsList.map(
        (data) => SizedBox(
          width: double.infinity,
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 16),
              children: [
                TextSpan(
                  text: data.key.toString(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
                ),
                const TextSpan(text: ": "),
                TextSpan(text: data.value.join(", ")),
              ],
            ),
          ),
        ),
      ).toList(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("Schließen"),
      ),
    ],
  );
}

/// Dialog zum Auswählen der gewünschten anzuzeigenden Raumtypen
class SetRoomTypeFilterDialog extends StatefulWidget {
  const SetRoomTypeFilterDialog({super.key});

  @override
  State<SetRoomTypeFilterDialog> createState() => _SetRoomTypeFilterDialogState();
}

class _SetRoomTypeFilterDialogState extends State<SetRoomTypeFilterDialog> {
  @override
  Widget build(BuildContext context) {
    final prefs = Provider.of<Preferences>(context);
    return AlertDialog(
      title: Text("Raumtypen ausblenden"),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        child: ListenableBuilder(
          listenable: prefs,
          builder: (ctx, _) => ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: listOfRoomTypeIdStrings().map((data) {
              ListTile? genLT(String roomTypeID) {
                return ListTile(
                  contentPadding: EdgeInsets.only(left: 0.0, right: 0.0),
                  leading: IconButton.outlined(
                      icon: Icon(prefs.filteredRoomTypes.contains(roomTypeID) ? MdiIcons.eye : MdiIcons.eyeOff, size: 20),
                      onPressed: () =>
                        prefs.filteredRoomTypes.contains(roomTypeID)
                            ? (prefs.removeFilteredRoomType(roomTypeID))
                            : (prefs.addFilteredRoomType(roomTypeID))
                  ),
                  title: Text(
                   fromIdStringToString(roomTypeID),
                   style: Theme.of(context).textTheme.bodyLarge,
                  ),
                );
              }
              final lt = genLT(data);
              return lt;
            }).where((lt) => lt != null).toList().cast(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            freeRoomDisplayKey.currentState?.refreshData();
          },
          child: const Text("Schließen"),
        ),
      ],
    );
  }
}