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
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/rainbow.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

final yourPlanDisplayKey = GlobalKey<StuPlanDisplayState>();

class YourPlanPage extends StatelessWidget {
  const YourPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stdata = Provider.of<StuPlanData>(context);
    return Stack(
      children: [
        RainbowWrapper(builder: (_, color) => Container(color: color?.withOpacity(.5))),
        Column(
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: StuPlanDisplay(
                  key: yourPlanDisplayKey,
                  selected: Provider.of<AppState>(context).userType == UserType.teacher ? stdata.selectedTeacherName! : stdata.selectedClassName!,
                  mode: SPDisplayMode.yourPlan,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

void yourStuPlanEditAction() {
  final state = Provider.of<AppState>(globalScaffoldContext, listen: false);
  state.infoScreen ??= (state.userType != UserType.teacher)
      ? stuPlanPupilIntroScreens()
      : stuPlanTeacherIntroScreens();
}

void yourStuPlanRefreshAction() {
  yourPlanDisplayKey.currentState?.forceRefreshData();
}

void yourStuPlanJumpToStartAction() {
  yourPlanDisplayKey.currentState?.jumpToStartDate();
}

const stuPlanInfoKey = "stu_plan_info";

Future<bool> stuPlanShowInfoDialog(BuildContext context) async {
  final internal = Provider.of<InternalState>(context, listen: false);
  final sie = Provider.of<Preferences>(context, listen: false).preferredPronoun == Pronoun.sie;
  // internal.infosShown = internal.infosShown..clear();
  if (!internal.infosShown.contains(stuPlanInfoKey)) {
    const bold = TextStyle(fontWeight: FontWeight.bold);
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Info zum Vertretungsplan"),
      content: Text.rich(TextSpan(
        style: const TextStyle(fontSize: 16),
        children: [
          TextSpan(text: "${sie ? "Sie können" : "Du kannst"} mehr Infos zu Stunden ansehen, "),
          TextSpan(text: "indem ${sie ? "Sie diese antippen" : "Du sie antippst"}", style: bold),
          const TextSpan(text: "!\n"),
          TextSpan(text: "Außerdem ${sie ? "können Sie" : "kannst Du"} auch durch "),
          const TextSpan(text: "Wischen nach rechts und links", style: bold),
          const TextSpan(text: " Tage wechseln.\n\n"),
          const TextSpan(text: "Diese Info wird nur einmalig angezeigt."),
        ],
      )),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("OK"),
        ),
      ],
    ));
    internal.addInfoShown(stuPlanInfoKey);
  }
  return true;
}

Widget generateLessonInfoDialog(BuildContext context, VPLesson lesson, VPCSubjectS? subject, String? classNameToReplace, bool lastRoomUsageInDay) {
  return AlertDialog(
    title: Text("Infos zur ${lesson.schoolHour}. Stunde"),
    content: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lesson.startTime != null && lesson.endTime != null) Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  const WidgetSpan(child: Icon(Icons.access_time, color: Colors.grey)),
                  const TextSpan(text: " "),
                  TextSpan(text: "${lesson.startTime} bis ${lesson.endTime}"),
                ],
              ),
            ),
          ),
          Flexible(
            child: Padding(
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
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(MdiIcons.humanMaleBoard, color: Colors.grey)),
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
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(MdiIcons.door, color: Colors.grey)),
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
                  const WidgetSpan(child: Icon(MdiIcons.informationOutline, color: Colors.grey)),
                  const TextSpan(text: " "),
                  TextSpan(text: lesson.infoText),
                ],
              ),
            ),
          ),
        ],
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

Widget generateExamInfoDialog(BuildContext context, VPExam exam) {
  return AlertDialog(
    title: Text("Infos zur Klausur in ${exam.subject}"),
    content: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exam.begin != "") Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(MdiIcons.clock, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: exam.begin),
                  ],
                ),
              ),
            ),
          ),
          if (exam.hour != "") Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(MdiIcons.timelineClock, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: "${exam.hour}. Stunde"),
                  ],
                ),
              ),
            ),
          ),
          if (exam.duration != "") Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(MdiIcons.clockStart, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: "${exam.duration} min"),
                  ],
                ),
              ),
            ),
          ),
          if (exam.year != "") Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(MdiIcons.accountGroup, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: "Jahrgang ${exam.year}"),
                  ],
                ),
              ),
            ),
          ),
          if (exam.subject != "") Flexible(
            child: Padding(
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
          ),
          if (exam.teacher != "") Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(MdiIcons.humanMaleBoard, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: exam.teacher),
                  ],
                ),
              ),
            ),
          ),
          if (exam.info != "") Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(MdiIcons.informationOutline, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: exam.info),
                  ],
                ),
              ),
            ),
          ),
        ],
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
