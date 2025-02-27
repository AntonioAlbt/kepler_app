import 'package:flutter/material.dart';
import 'package:kepler_app/libs/custom_events.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/pages/free_rooms.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

// TODO: Dialoge stattdessen als Popup-Panels von unten erstellen

/// Dialog mit mehr Infos zu einer Stunde erstellen
Widget generateLessonInfoDialog(BuildContext context, VPLesson lesson, VPCSubjectS? subject, String? classNameToReplace, bool lastRoomUsageInDay, DateTime date) {
  return AlertDialog(
    title: Text("Infos zur ${lesson.schoolHour}. Stunde"),
    content: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lesson.startTime != null && lesson.endTime != null) Text.rich(
              TextSpan(
                children: [
                  const WidgetSpan(child: Icon(Icons.access_time, color: Colors.grey)),
                  const TextSpan(text: " "),
                  TextSpan(text: "${lesson.startTime} bis ${lesson.endTime}"),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(Icons.school, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: lesson.subjectCode.replaceFirst(classNameToReplace ?? "funny joke.", "")),
                    if (lesson.subjectChanged) const TextSpan(text: ", "),
                    if (lesson.subjectChanged)
                      const TextSpan(
                        text: "geändert",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    if (lesson.subjectChanged && subject != null && subject.subjectCode != lesson.subjectCode) TextSpan(
                      text: " (sonst ${subject.subjectCode}${(subject.additionalDescr != null) ? " (${subject.additionalDescr})" : ""})"
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(child: Icon(MdiIcons.humanMaleBoard, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: (lesson.teacherCode == "") ? "---" : lesson.teacherCode),
                    if (lesson.teacherChanged) const TextSpan(text: ", "),
                    if (lesson.teacherChanged)
                      const TextSpan(
                        text: "geändert",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    if (lesson.teacherChanged && subject != null && subject.teacherCode != lesson.teacherCode) TextSpan(
                      text: " (sonst ${subject.teacherCode})"
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(child: Icon(MdiIcons.door, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: (lesson.roomCodes.isEmpty) ? "---" : lesson.roomCodes.join(", ")),
                    if (lesson.roomChanged) const TextSpan(text: ", "),
                    if (lesson.roomChanged)
                      const TextSpan(
                        text: "geändert",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
            ),
            if (lastRoomUsageInDay) Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(Icons.last_page, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: "${lesson.roomCodes.length == 1 ? "Der Raum" : "Mind. einer der Räume"} wird das letzte Mal für den Tag verwendet."),
                  ],
                ),
              ),
            ),
            if (lesson.infoText != "") Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(child: Icon(MdiIcons.informationOutline, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: lesson.infoText),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      /// Shortcut zum entsprechenden Raumplan - natürlich nur sichtbar, wenn ein Raum existiert
      /// und der betreffende Raum auch der App bekannt ist (also im JKG vorhanden ist)
      /// und die betreffende Seite nicht schon der Raumplan ist - dann würde der Link
      /// auf genau diese Seite mit genau dem aktuellen Raum verweisen -> das wäre sinnlos
      /// Dabei wird immer der erste Raum von evtl. mehreren vorhandenen verwendet
      /// toString, weil es ohne seltsamerweise nicht funktioniert hat
      if (lesson.roomCodes.isNotEmpty
          && allKeplerRooms.contains(lesson.roomCodes.first)
          && ((Provider.of<AppState>(context, listen: false).selectedNavPageIDs).toString() != [StuPlanPageIDs.main, StuPlanPageIDs.roomPlans].toString())
          && Provider.of<Preferences>(context, listen: false).stuPlanShowRoomPlanLink
      ) TextButton(
        onPressed: () {
          Navigator.pop(context);
          Provider.of<InternalState>(context, listen: false).lastSelectedRoomPlan = lesson.roomCodes.first;
          Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.roomPlans];
        },
        child: Text("Zum Raumplan${lesson.roomCodes.length > 1 ? " für ${lesson.roomCodes.first}" : ""}"),
      ),
      TextButton(
        onPressed: () async {
          final event = await showModifyEventDialog(context, date, CustomEvent(title: "Ereignis", date: date, notify: false, startLesson: lesson.schoolHour, endLesson: lesson.schoolHour));
          if (event != null) {
            if (!context.mounted) return;
            Provider.of<CustomEventManager>(context, listen: false).addEvent(event);
          }
        },
        child: Text("Ereignis erstellen"),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("Schließen"),
      ),
    ],
  );
}

/// Dialog mit mehr Infos zu einer Klausur erstellen
Widget generateExamInfoDialog(BuildContext context, VPExam exam) {
  return AlertDialog(
    title: Text("Infos zur Klausur in ${exam.subject}"),
    content: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (exam.begin != "") Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(child: Icon(MdiIcons.clock, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: exam.begin),
                  ],
                ),
              ),
            ),
            if (exam.hour != "") Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(child: Icon(MdiIcons.timelineClock, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: "${exam.hour}. Stunde"),
                  ],
                ),
              ),
            ),
            if (exam.duration != "") Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(child: Icon(MdiIcons.clockStart, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: "${exam.duration} min"),
                  ],
                ),
              ),
            ),
            if (exam.year != "") Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(child: Icon(MdiIcons.accountGroup, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: "Jahrgang ${exam.year}"),
                  ],
                ),
              ),
            ),
            if (exam.subject != "") Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(Icons.school, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: exam.subject),
                  ],
                ),
              ),
            ),
            if (exam.teacher != "") Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(child: Icon(MdiIcons.humanMaleBoard, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: exam.teacher),
                  ],
                ),
              ),
            ),
            if (exam.info != "") Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(child: Icon(MdiIcons.informationOutline, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: exam.info),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("Schließen"),
      ),
    ],
  );
}

