import 'package:enough_serialization/enough_serialization.dart';

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
  set startLesson(int? val) => attributes["start_l"];
  /// Endschulstunde, nur erforderlich, wenn an Schulstunden gebunden
  int? get endLesson => attributes["end_l"];
  set endLesson(int? val) => attributes["end_l"];

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

  @override
  String toString() {
    return 'CustomEvent{title: $title, description: $description, startTime: $startTime, endTime: $endTime, startLesson: $startLesson, endLesson: $endLesson, notify: $notify, repeatId: $repeatId}';
  }
}
