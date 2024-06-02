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
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';

/// all of this is subject to change because of building "updates"
final allKeplerRooms = [
  "K08", "K10",
  ...rooms("0", 4, 12, [5, 7]),
  ...rooms("1", 8, 16, [12, 14]),
  ...rooms("2", 1, 16, [6, 7, 12, 14]),
  ...rooms("3", 1, 17, [3, 7, 14, 16]),
  "TH", "Jb1", "Jb2",
];
enum RoomType {
  compSci, technic, sports, specialist, music, art;
  @override
  String toString() => {
    RoomType.art: "Kunstzimmer",
    RoomType.compSci: "Informatikkabinette",
    RoomType.music: "Musikzimmer",
    RoomType.specialist: "Fachräume",
    RoomType.sports: "Sporthallen",
    RoomType.technic: "TC-Räume",
  }[this]!;
}
// this even more
final specialRoomInfo = {
  RoomType.compSci: ["K08", "K10", "202"],
  RoomType.technic: ["004", "006"],
  RoomType.sports: ["TH", "Jb1", "Jb2"],
  RoomType.specialist: ["113", "115", "116", "213", "215", "313", "315"],
  RoomType.music: ["317"],
  RoomType.art: ["302"],
};
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

/// including start and end
List<String> rooms(String prefix, int start, int end, List<int> excludes) {
  final rooms = <String>[];
  for (var i = start; i <= end; i++) {
    if (excludes.contains(i)) continue;
    rooms.add("$prefix${i.toString().padLeft(2, "0")}");
  }
  return rooms;
}

class FreeRoomsPage extends StatelessWidget {
  const FreeRoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: StuPlanDisplay(
        key: freeRoomDisplayKey,
        mode: SPDisplayMode.freeRooms,
        selected: '',
      ),
    );
  }
}

void freeRoomRefreshAction() {
  freeRoomDisplayKey.currentState?.forceRefreshData();
}

Widget generateFreeRoomsClickDialog(BuildContext context, List<MapEntry<RoomType?, List<String>>> freeRoomsList, int hour) {
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
                  text: data.key?.toString() ?? "Allgemein",
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
