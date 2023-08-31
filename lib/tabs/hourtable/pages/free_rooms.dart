import 'package:flutter/material.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';

/// all of this is subject to change because of building "updates"
final allKeplerRooms = [
  "K08", "K10",
  ...rooms("0", 4, 13, [6, 7]), "TH",
  ...rooms("1", 8, 16, [12, 14]),
  ...rooms("2", 1, 16, [6, 7, 12, 14]),
  ...rooms("3", 1, 17, [3, 7, 14, 16]),
  "Jb1", "Jb2",
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
  RoomType.compSci: ["K08", "K10", "013"],
  RoomType.technic: ["004", "005"],
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
        className: '',
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
