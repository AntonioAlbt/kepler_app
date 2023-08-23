import 'package:flutter/material.dart';

final allKeplerRooms = [
  "K08", "K10",
  ...rooms("0", 4, 13, [6, 7]), "TH",
  ...rooms("1", 8, 16, [12, 14]),
  ...rooms("2", 1, 16, [6, 7, 14]),
  ...rooms("3", 1, 16, [3, 7, 14]),
  "Jb1", "Jb2",
];

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
    return const Text("Freie Zimmer");
  }
}
