import 'dart:developer' show log;

import 'package:datetime_picker_formfield_new/datetime_picker_formfield.dart';
import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:provider/provider.dart';
import 'package:synchronized/synchronized.dart';

/// Speicherpfad für die Events
Future<String> get customEventDataFilePath async => "${await userDataDirPath}/custom-events.json";

class CustomEvent extends SerializableObject {
  /// Titel des Events
  String get title => attributes["title"];
  set title(String val) => attributes["title"] = val;

  /// Beschreibung
  String? get description => attributes["desc"];
  set description(String? val) => attributes["desc"] = val;

  /// Datum für Ereignis (Uhrzeit wird ignoriert)
  DateTime? get date => attributes.containsKey("date") && attributes["date"] != null ? DateTime.parse(attributes["date"]) : null;
  set date(DateTime? val) => attributes["date"] = val?.toString();

  /// Startzeit, nur erforderlich, wenn nicht an Schulstunden gebunden
  HMTime? get startTime => attributes.containsKey("start") && attributes["start"] != null ? HMTime.fromTimeString(attributes["start"]) : null;
  set startTime(HMTime? val) => attributes["start"] = val?.toString();
  /// Endzeit, nur erforderlich, wenn nicht an Schulstunden gebunden
  HMTime? get endTime => (attributes.containsKey("end") && attributes["end"] != null) ? HMTime.fromTimeString(attributes["end"]) : null;
  set endTime(HMTime? val) => attributes["end"] = val?.toString();

  /// Startschulstunde, nur erforderlich, wenn an Schulstunden gebunden
  int? get startLesson => attributes["start_l"];
  set startLesson(int? val) => attributes["start_l"] = val;
  /// Endschulstunde, nur erforderlich, wenn an Schulstunden gebunden
  int? get endLesson => attributes["end_l"];
  set endLesson(int? val) => attributes["end_l"] = val;

  /// will der Ersteller über dieses Ereignis benachrichtigt werden?
  bool get notify => attributes["notif"] ?? true;
  set notify(bool val) => attributes["notif"] = val;

  /// wenn ein Ereignis mehrfach wiederholt wird, können alle erstellten Ereignisse eine zufällige ID hier zugewiesen 
  /// bekommen, um dann z.B. alle zu löschen, wenn eins gelöscht wird (oder alle zu ändern)
  int? get repeatId => attributes["rid"];
  set repeatId(int? val) => attributes["rid"] = val;

  CustomEvent({
    required String title,
    String? description,
    required DateTime date,
    HMTime? startTime,
    HMTime? endTime,
    int? startLesson,
    int? endLesson,
    required bool notify,
    int? repeatId,
  }) {
    this.title = title;
    this.description = description;
    this.date = date;
    this.startTime = startTime;
    this.endTime = endTime;
    this.startLesson = startLesson;
    this.endLesson = endLesson;
    this.notify = notify;
    this.repeatId = repeatId;
  }

  CustomEvent.empty();

  CustomEvent copyWith({
    String? title,
    String? description,
    DateTime? date,
    HMTime? startTime,
    HMTime? endTime,
    int? startLesson,
    int? endLesson,
    bool? notify,
    int? repeatId,
  }) {
    return CustomEvent(
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date!,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startLesson: startLesson ?? this.startLesson,
      endLesson: endLesson ?? this.endLesson,
      notify: notify ?? this.notify,
      repeatId: repeatId ?? this.repeatId,
    );
  }

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

  List<CustomEvent> get events => attributes["events"] ?? [];
  // List<CustomEvent> get events => [
  //   CustomEvent(title: "Test Event", description: "Hier könnte Werbung stehen?", date: DateTime.now(), startLesson: 2, notify: false),
  //   CustomEvent(title: "keine Schule oder so", description: "sehr sehr viel Text der gar nicht mehr aufhört was ist denn hier los warum geht denn das immer weiter", date: DateTime.now(), startLesson: 2, notify: false),
  //   CustomEvent(title: "Testere Eventere", description: "", date: DateTime.now(), startLesson: 2, notify: false),
  //   CustomEvent(title: "Längeres Event", description: "mehrere Stunden", date: DateTime.now(), startLesson: 2, endLesson: 5, notify: false),
  //   CustomEvent(title: "Testere Eventere", description: "", date: DateTime.now(), startTime: HMTime(10, 55), endTime: HMTime(15, 43), notify: false),
  //   CustomEvent(title: "Testere 2 Eventere: dbl fun, longer title than ever before", description: "das ist ein mehrstündiges direktes Event", date: DateTime.now(), startTime: HMTime(2, 2), endTime: HMTime(14, 3), notify: false),
  // ];
  set events(List<CustomEvent> events) => _setSaveNotify("events", events);
  void addEvent(CustomEvent event) {
    events = events..add(event);
  }

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
        onTap: (showInfoDialog)
          ? () => showDialog(
              context: context,
              builder: (dialogCtx) => generateEventInfoDialog(dialogCtx, event))
          : null,
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
                "${event.startTime}${event.endTime != null ? "\nbis\n${event.endTime}" : ""}",
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
                  if (event.description != null) Text(
                    event.description!.split("\n").length <= 2 ? event.description! : "${event.description!.split("\n").take(2).join("\n")}...",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

Future<CustomEvent?> showAddEventDialog(BuildContext context, DateTime selected) async {
  return await showDialog<CustomEvent>(
    context: context,
    builder: (ctx) => ManageEventDialog(selectedDate: selected, add: true),
  );
}

class ManageEventDialog extends StatefulWidget {
  final bool add;
  final CustomEvent? prefilledData;
  final DateTime selectedDate;
  const ManageEventDialog({super.key, required this.selectedDate, required this.add, this.prefilledData});

  @override
  State<ManageEventDialog> createState() => _ManageEventDialogState();
}

class _ManageEventDialogState extends State<ManageEventDialog> {
  CustomEvent event = CustomEvent.empty();
  String timeVariant = "s";
  late TextEditingController _titleInput;
  late TextEditingController _descInput;
  late TextEditingController _startLessonInput;
  late TextEditingController _endLessonInput;
  bool userChangedEndLesson = false;

  bool showErrors = false;
  bool titleValid = false;
  String? timeError;

  @override
  void initState() {
    _titleInput = TextEditingController();
    _descInput = TextEditingController();
    _startLessonInput = TextEditingController();
    _endLessonInput = TextEditingController();

    event.date = widget.selectedDate;

    if (widget.prefilledData != null) {
      event = widget.prefilledData!.copyWith();
      userChangedEndLesson = event.startLesson != event.endLesson && !(event.startLesson != null && event.endLesson == null);
      _titleInput.text = event.title;
      if (event.description != null) _descInput.text = event.description!;
      if (event.startLesson != null) {
        _startLessonInput.text = event.startLesson.toString();
        _endLessonInput.text = (event.endLesson ?? event.startLesson).toString();
      }
      showErrors = true;
      titleValid = true;
      timeVariant = event.startTime != null && event.endTime != null ? "z" : "s";
    }

    super.initState();
  }

  @override
  void dispose() {
    _titleInput.dispose();
    _descInput.dispose();
    _startLessonInput.dispose();
    _endLessonInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Ereignis ${widget.add ? "hinzufügen" : "bearbeiten"}"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                label: Text("Titel des Ereignisses"),
                errorText: showErrors && !titleValid ? "Titel ist erforderlich." : null,
              ),
              onChanged: (val) {
                event.title = val;
                setState(() {
                  titleValid = val.isNotEmpty;
                });
              },
              controller: _titleInput,
            ),
            TextField(
              minLines: 1,
              maxLines: 10,
              decoration: InputDecoration(
                label: Text("Beschreibung des Ereignisses"),
              ),
              onChanged: (val) => event.description = val,
              controller: _descInput,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: DateTimeField(
                initialValue: widget.selectedDate,
                onChanged: (val) => setState(() => event.date = val),
                format: DateFormat("dd.MM.yyyy"),
                onShowPicker: (context, current) => showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDate: current,
                ),
                decoration: InputDecoration(
                  label: Text("Datum"),
                  isDense: true,
                  contentPadding: const EdgeInsets.only(bottom: 4, top: 4),
                ),
                resetIcon: null,
              ),
            ),
            if (event.date != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Align(alignment: Alignment.centerLeft, child: Text("Welches Zeitsystem verwenden?")),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: DropdownButton(
                  menuWidth: 200,
                  value: timeVariant,
                  items: [
                    DropdownMenuItem(value: "s", child: Text("Schulstunden")),
                    DropdownMenuItem(value: "z", child: Text("Zeitstunden")),
                  ],
                  onChanged: (val) {
                    if (val == timeVariant) return;
                    if (showErrors) checkTimeError();
                    
                    setState(() {
                      timeVariant = val!;
                      event.startLesson = null;
                      event.endLesson = null;
                      event.endTime = null;
                      _startLessonInput.text = "";
                      _endLessonInput.text = "";
                    });
                  },
                ),
              ),
              if (timeVariant == "s") Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Text("von  "),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 25),
                      child: TextField(
                        controller: _startLessonInput,
                        onChanged: (val) {
                          event.startLesson = int.tryParse(val);
                          if (!userChangedEndLesson) _endLessonInput.text = val;
                          checkTimeError();
                        },
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.only(),
                          isDense: true,
                        ),
                      ),
                    ),
                    Text(". Stunde bis  "),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 25),
                      child: TextField(
                        controller: _endLessonInput,
                        onChanged: (val) {
                          setState(() => userChangedEndLesson = true);
                          event.endLesson = int.tryParse(val);
                          checkTimeError();
                        },
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.only(),
                          isDense: true,
                        ),
                      ),
                    ),
                    Text(". Stunde")
                  ],
                ),
              ) else if (timeVariant == "z") Row(
                children: [
                  Text("von  "),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 75),
                    child: DateTimeField(
                      initialValue: event.startTime?.toDateTime(null),
                      onChanged: (time) {
                        event.startTime = time != null ? HMTime.fromDateTime(time) : null;
                        checkTimeError();
                      },
                      format: DateFormat("HH:mm"),
                      onShowPicker: (context, current) async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: current != null ? TimeOfDay.fromDateTime(current) : TimeOfDay.now(),
                        );
                        if (picked == null) return null;

                        return HMTime(picked.hour, picked.minute).toDateTime(null);
                      },
                      decoration: InputDecoration(
                        label: Text("Startzeit"),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      resetIcon: null,
                    ),
                  ),
                  Text(" bis  "),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 75),
                    child: DateTimeField(
                      initialValue: event.endTime?.toDateTime(null),
                      format: DateFormat("HH:mm"),
                      onShowPicker: (context, current) async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: current != null ? TimeOfDay.fromDateTime(current) : TimeOfDay.now(),
                        );
                        if (picked == null) return null;
                        
                        return HMTime(picked.hour, picked.minute).toDateTime(null);
                      },
                      decoration: InputDecoration(
                        label: Text("Endzeit"),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      resetIcon: null,
                      onChanged: (time) {
                        event.endTime = time != null ? HMTime.fromDateTime(time) : null;
                        checkTimeError();
                      },
                    ),
                  ),
                ],
              ),
              if (timeError != null && showErrors) Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    timeError!,
                    style: TextStyle(
                      color: hasDarkTheme(context) ? Colors.red.shade300 : Colors.red.shade800,
                    ),
                  ),
                ),
              ),
            ],
            // TODO: allow to choose event.notify, add inputs for repeating events
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () {
          setState(() {
            showErrors = true;
          });
          checkTimeError();

          if (!titleValid || timeError != null) return;
          Navigator.pop(context, event);
        }, child: Text("Speichern")),
        TextButton(onPressed: () => Navigator.pop(context, null), child: Text("Abbrechen")),
      ],
    );
  }

  void checkTimeError() {
    final err = determineTimeError();
    setState(() {
      timeError = err;
    });
  }
  String? determineTimeError() {
    if (event.date == null) {
      // return "Kein Datum ausgewählt.";
      return "";
    }
    if (timeVariant == "s") {
      if (event.startLesson == null) return "Keine Startstunde angegeben.";
      if (event.startLesson! < 0 || (event.endLesson != null && event.endLesson! < 0)) return "Stunde muss größer als 0 sein.";
      if (event.endLesson != null && event.startLesson! > event.endLesson!) return "Endstunde liegt vor Startstunde.";
      if (event.startLesson! > 16 || (event.endLesson ?? 0) > 16) return "Kann maximal bis zur 16. Stunde gehen.";
    } else if (timeVariant == "z") {
      if (event.startTime == null) return "Kein Start angegeben.";
      if (event.endTime == null) return "Kein Ende angegeben.";
      if (event.startTime! > event.endTime!) return "Ende liegt vor Start.";
    }
    return null;
  }
}

Future<DateTime?> showDateTimePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  initialDate ??= DateTime.now();
  firstDate ??= initialDate.subtract(const Duration(days: 365 * 100));
  lastDate ??= firstDate.add(const Duration(days: 365 * 200));

  final DateTime? selectedDate = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );

  if (selectedDate == null) return null;

  if (!context.mounted) return selectedDate;

  final TimeOfDay? selectedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(selectedDate),
  );

  return selectedTime == null
      ? selectedDate
      : DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );
}

Widget generateEventInfoDialog(BuildContext context, CustomEvent event) {
  return AlertDialog(
    title: Text("Info zum Ereignis"),
    content: DefaultTextStyle(
      style: TextStyle(fontSize: 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.label),
                Expanded(child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(event.title, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20)),
                )),
              ],
            ),
            if (event.description != null) Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                children: [
                  Icon(Icons.description),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(event.description ?? "???"),
                  )),
                ],
              ),
            ),
            if (event.date != null) Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                children: [
                  Icon(Icons.calendar_today),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(DateFormat("dd.MM.yyyy").format(event.date!)),
                  )),
                ],
              ),
            ),
            if (event.startTime != null && event.endTime != null) Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                children: [
                  Icon(Icons.timer),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("von ${event.startTime} bis ${event.endTime}"),
                  )),
                ],
              ),
            ),
            if (event.startLesson != null) Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                children: [
                  Icon(Icons.timer),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("${event.endLesson != null ? "von " : ""}${event.startLesson}. Stunde${event.endLesson != null ? " bis ${event.endLesson}. Stunde" : ""}"),
                  )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                children: [
                  Icon(Icons.notifications),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: "Benachrichtigung: "),
                            TextSpan(
                              text: "bald verfügbar",
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.only(top: 1),
            //   child: Row(
            //     children: [
            //       Icon(Icons.refresh),
            //       Expanded(
            //         child: Padding(
            //           padding: const EdgeInsets.all(8.0),
            //           child: Text.rich(
            //             TextSpan(
            //               children: [
            //                 TextSpan(text: "Wiederholtes Ereignis: "),
            //                 TextSpan(
            //                   text: "bald verfügbar",
            //                   style: TextStyle(fontStyle: FontStyle.italic),
            //                 ),
            //               ],
            //             ),
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (ctx) => ManageEventDialog(selectedDate: event.date ?? DateTime.now(), add: false, prefilledData: event),
          ).then((newEvt) {
            if (newEvt == null) return;
            // ignore: use_build_context_synchronously
            final customEvtMgr = Provider.of<CustomEventManager>(globalScaffoldContext, listen: false);
            customEvtMgr.events.remove(event);
            customEvtMgr.addEvent(newEvt);
          });
        },
        child: Text("Bearbeiten"),
      ),
      TextButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: Text("Schließen"),
      ),
    ],
  );
}
