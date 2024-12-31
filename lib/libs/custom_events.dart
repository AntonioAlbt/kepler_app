import 'dart:developer' show log;

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:synchronized/synchronized.dart';

/// Speicherpfad für die Events
Future<String> get customEventDataFilePath async => "${await userDataDirPath}/custom-events.json";

class CustomEvent extends SerializableObject {
  /// Titel des Events
  String get title => attributes["title"];
  set title(String val) => attributes["title"] = val;

  /// Beschreibung
  String get description => attributes["desc"];
  set description(String val) => attributes["desc"] = val;

  /// Startzeit, oder nur für Datum wenn an Schulstunden gebunden
  DateTime get startTime => DateTime.parse(attributes["start"]);
  set startTime(DateTime val) => attributes["start"] = val.toIso8601String();
  /// Endzeit, nur erforderlich, wenn nicht an Schulstunden gebunden
  DateTime? get endTime => (attributes.containsKey("end") && attributes["end"] != null) ? DateTime.parse(attributes["end"]) : null;
  set endTime(DateTime? val) => attributes["end"] = val?.toIso8601String();

  /// falls das Event an Schulstunden gebunden ist (start/endLesson != null), wird startTime als Datum verwendet (Zeit wird ignoriert)
  int? get startLesson => attributes["start_l"];
  set startLesson(int? val) => attributes["start_l"] = val;
  /// Endschulstunde, nur erforderlich, wenn an Schulstunden gebunden
  int? get endLesson => attributes["end_l"];
  set endLesson(int? val) => attributes["end_l"] = val;

  /// will der Ersteller davor benachrichtigt werden?
  bool get notify => attributes["notif"];
  set notify(bool val) => attributes["notif"] = val;

  /// wenn ein Event mehrfach wiederholt wird, können alle erstellten Events eine zufällige ID hier zugewiesen 
  /// bekommen, um dann z.B. alle zu löschen, wenn eins gelöscht wird (oder alle zu ändern)
  int? get repeatId => attributes["rid"];
  set repeatId(int? val) => attributes["rid"] = val;

  CustomEvent({
    required String title,
    required String description,
    required DateTime startTime,
    DateTime? endTime,
    int? startLesson,
    int? endLesson,
    required bool notify,
    int? repeatId,
  }) {
    this.title = title;
    this.description = description;
    this.startTime = startTime;
    this.endTime = endTime;
    this.startLesson = startLesson;
    this.endLesson = endLesson;
    this.notify = notify;
    this.repeatId = repeatId;
  }

  CustomEvent.empty();

  @override
  String toString() {
    return 'CustomEvent{title: $title, description: $description, startTime: $startTime, endTime: $endTime, startLesson: $startLesson, endLesson: $endLesson, notify: $notify, repeatId: $repeatId}';
  }
}

class CustomEventManager extends SerializableObject with ChangeNotifier {
  CustomEventManager() {
    objectCreators["events"] = (_) => <CustomEvent>[];
    objectCreators["events.value"] = (_) => CustomEvent.empty();
  }

  // List<CustomEvent> get events => attributes["events"] ?? [];
  List<CustomEvent> get events => [
    CustomEvent(title: "Test Event", description: "Hier könnte Werbung stehen?", startTime: DateTime.now(), startLesson: 2, notify: false),
    CustomEvent(title: "keine Schule oder so", description: "sehr sehr viel Text der gar nicht mehr aufhört was ist denn hier los warum geht denn das immer weiter", startTime: DateTime.now(), startLesson: 2, notify: false),
    CustomEvent(title: "Testere Eventere", description: "", startTime: DateTime.now(), startLesson: 2, notify: false),
    CustomEvent(title: "Längeres Event", description: "mehrere Stunden", startTime: DateTime.now(), startLesson: 2, endLesson: 5, notify: false),
    CustomEvent(title: "Testere Eventere", description: "", startTime: DateTime.now(), endTime: DateTime.now().add(const Duration(hours: 2)), notify: false),
    CustomEvent(title: "Testere 2 Eventere: dbl fun, longer title than ever before", description: "das ist ein mehrstündiges direktes Event", startTime: DateTime.now().add(const Duration(minutes: -5, hours: -1)), endTime: DateTime.now().add(const Duration(minutes: -50)), notify: false),
  ];
  set events(List<CustomEvent> events) => _setSaveNotify("events", events);

  void _setSaveNotify(String key, dynamic data) {
    attributes[key] = data;
    notifyListeners();
    save();
  }
  
  final _serializer = Serializer();
  bool loaded = false;
  final Lock _fileLock = Lock();
  Future<void> save() async {
    if (_fileLock.locked) log("The file lock for CustomEventManager (file: cache/custom-events.json) is still locked!!! This means waiting...");
    _fileLock.synchronized(() async => await writeFile(await customEventDataFilePath, _serialize()));
  }
  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    try {
      _serializer.deserialize(json, this);
    } catch (e, s) {
      log("Error while decoding json for CustomEventManager from file:", error: e, stackTrace: s);
      logCatch("ce_data", e, s);
      return;
    }
    loaded = true;
  }
}

final _timeFormat = DateFormat("HH:mm");

/// zeigt Event schön formatiert an (mit Dialog beim Antippen)
class CustomEventDisplay extends StatelessWidget {
  /// anzuzeigendes Event
  final CustomEvent event;
  /// Stunde des vorherigen Events (damit Text mit Stunde nur einmal vor mehreren Events in derselben Stunde
  /// angezeigt wird)
  final int? previousDisplayHour;
  /// soll der Info-Dialog beim Antippen angezeigt werden?
  final bool showInfoDialog;

  const CustomEventDisplay(this.event, this.previousDisplayHour, {super.key, this.showInfoDialog = true});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontSize: 18,
        height: 0,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        /// TODO: add event info dialog, with edit option
        // onTap: (showInfoDialog)
        //     ? () => showDialog(
        //         context: context,
        //         builder: (dialogCtx) => generateLessonInfoDialog(dialogCtx, lesson, subject, classNameToStrip, lastRoomUsageInDay))
        //     : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (event.startLesson != null) Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 26,
                child: (previousDisplayHour != event.startLesson || (event.endLesson != null && event.endLesson != event.startLesson))
                    ? Text("${event.startLesson}${event.endLesson != null ? ".\n- " : ""}${event.endLesson ?? ""}. ")
                    : const SizedBox.shrink(),
              ),
            ) else Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                "${_timeFormat.format(event.startTime)}${event.endTime != null ? "\nbis\n${_timeFormat.format(event.endTime!)}" : ""}",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.calendar_today, size: 14),
                      ),
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(fontWeight: FontWeight.w500, color: hasDarkTheme(context) ? Colors.blue.shade200 : Colors.blue.shade900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (event.description != "") Text(
                    event.description,
                    style: TextStyle(fontSize: 15, color: hasDarkTheme(context) ? Colors.blue.shade200 : Colors.blue.shade900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
