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
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/rainbow.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

/// zwei Keys, da Bearbeiten des Planes Zugriff auf den State der Seite selbst benötigt

/// zum Neuladen und "Springe zum heutigen Tag"
final yourPlanDisplayKey = GlobalKey<StuPlanDisplayState>();
/// zum Plan bearbeiten
final yourPlanPageKey = GlobalKey<YourPlanPageState>();

class YourPlanPage extends StatefulWidget {
  YourPlanPage() : super(key: yourPlanPageKey);

  @override
  State<YourPlanPage> createState() => YourPlanPageState();
}

class YourPlanPageState extends State<YourPlanPage> {
  /// gerade ausgewählter Plan, bestehend aus ( id, Klassenname/Lehrerkürzel )
  /// wenn id = 0 -> primärer Plan, sonst stdata.altSelectedClassNames[id - 1]
  /// 
  /// -> Achtung: bei Verwendung als Index immer `- 1` rechnen!
  late (int, String) selected;

  @override
  Widget build(BuildContext context) {
    return Consumer3<StuPlanData, AppState, Preferences>(
      builder: (context, stdata, state, prefs, _) {
        final mainSelected = state.userType == UserType.teacher ? stdata.selectedTeacherName! : stdata.selectedClassName!;
        return Stack(
          children: [
            RainbowWrapper(builder: (_, color) => Container(color: color?.withValues(alpha: .5))),
            Column(
              children: [
                if (prefs.showYourPlanAddDropdown) SizedBox(
                  height: selected.$1 > 0 ? 90 : 50,
                  child: AppBar(
                    scrolledUnderElevation: 5,
                    backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                    elevation: 5,
                    bottom: PreferredSize(
                      preferredSize: const Size(100, 100),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // extra IconButton, damit der DropdownButton in der Mitte ist
                              if (stdata.altSelectedClassNames.isEmpty) const IconButton(icon: Icon(Icons.abc, size: 20, color: Colors.transparent), onPressed: null),
                               DropdownButton<(int, String)>(
                                items: ([mainSelected, ...stdata.altSelectedClassNames].asMap().entries.map(
                                  (e) => classNameToIndexedDropdownItem(e.value, state.userType == UserType.teacher, e.key, e.key == 0 ? " (primär)" : null)
                                ).toList()..add(
                                  const DropdownMenuItem(
                                    value: (-153, "add"),
                                    child: Text("+ Stundenplan hinzufügen"),
                                  ),
                                )),
                                onChanged: (val) {
                                  final (i, _) = val!;
                                  if (i == -153) {
                                    showDialog(
                                      context: context,
                                      builder: (_) => const AddNewStuPlanDialog(),
                                    );
                                    return;
                                  }
                                  if (i == selected.$1) return;
                                  setState(() => selected = val);
                                  Provider.of<InternalState>(context, listen: false).lastSelectedClassYourPlan = i;
                                },
                                value: selected,
                              ),
                              /// da Benutzer, die nie einen anderen Plan hinzufügen wollen, das Dropdown vielleicht
                              /// nervig finden, kann man es ausblenden (und in den Einstellungen wieder einblenden)
                              if (stdata.altSelectedClassNames.isEmpty) IconButton(onPressed: () {
                                showDialog(context: context, builder: (ctx) => AlertDialog(
                                  title: const Text("Ausblenden?"),
                                  content: const Text("Soll die Möglichkeit zum Hinzufügen anderer Klassen/Stundenpläne wirklich ausgeblendet werden? Dies kann jederzeit in den Einstellungen geändert werden."),
                                  actions: [
                                    TextButton(onPressed: () {
                                      prefs.showYourPlanAddDropdown = false;
                                      Navigator.pop(ctx);
                                    }, child: const Text("Ja, ausblenden")),
                                    TextButton(onPressed: () {
                                      Navigator.pop(ctx);
                                    }, child: const Text("Nein")),
                                  ],
                                ));
                              }, icon: const Icon(Icons.visibility_off), iconSize: 20),
                            ],
                          ),
                          if (selected.$1 != 0) TextButton.icon(
                            icon: const Icon(Icons.delete, size: 16),
                            style: const ButtonStyle(
                              visualDensity: VisualDensity(horizontal: -4, vertical: -2),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Stundenplan entfernen"),
                                  content: Text("Stundenplan für ${selected.$2.contains("-") ? "Klasse" : "Jahrgang"} ${selected.$2} wirklich entfernen?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text("Abbrechen"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        stdata.removeAltSelection(selected.$1 - 1);
                                        if (!context.mounted) return;
                                        setState(() {
                                          selected = (0, mainSelected);
                                        });
                                        Provider.of<InternalState>(context, listen: false).lastSelectedClassYourPlan = 0;
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text("Entfernen"),
                                    ),
                                  ],
                                ),
                              );
                            },
                            label: const Text("Stundenplan entfernen"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: StuPlanDisplay(
                      key: yourPlanDisplayKey,
                      mode: SPDisplayMode.yourPlan,
                      selected: selected.$2,
                      selectedId: selected.$1,
                    ),
                  ),
                ),
              ],
            ),
            // Align(
            //   alignment: Alignment.bottomRight,
            //   child: Padding(
            //     padding: const EdgeInsets.all(16),
            //     child: Container(
            //       decoration: BoxDecoration(
            //         boxShadow: [BoxShadow(blurRadius: 15, spreadRadius: -10, offset: Offset(2, 2))]
            //       ),
            //       child: FloatingActionButton(
            //         elevation: 0,
            //         onPressed: () {}, // add calendar entry
            //         child: Icon(Icons.add),
            //       ),
            //     ),
            //   ),
            // ),
          ],
        );
      }
    );
  }

  /// automatisch damit umgehen, wenn der aktuell ausgewählte Eintrag entfernt oder verändert wird
  void stdataListener() {
    if (!context.mounted) return;
    final stdata = Provider.of<StuPlanData>(context, listen: false);
    final teacher = Provider.of<AppState>(context, listen: false).userType == UserType.teacher;
    if (
      (!teacher && stdata.selectedClassName != selected.$2 && selected.$1 == 0)
      || (stdata.altSelectedClassNames.length < selected.$1 && selected.$1 > 0)
    ) {
      setState(() {
        selected = (0, stdata.selectedClassName!);
      });
    } else if (teacher && stdata.selectedTeacherName != selected.$2 && selected.$1 == 0) {
      setState(() {
        selected = (0, stdata.selectedTeacherName!);
      });
    } else if (selected.$1 > 0 && stdata.altSelectedClassNames[selected.$1 - 1] != selected.$2) {
      setState(() {
        selected = (selected.$1, stdata.altSelectedClassNames[selected.$1 - 1]);
      });
    }
    Provider.of<InternalState>(context, listen: false).lastSelectedClassYourPlan = selected.$1;
  }

  @override
  void initState() {
    final stdata = Provider.of<StuPlanData>(context, listen: false);
    final lastIndex = Provider.of<InternalState>(context, listen: false).lastSelectedClassYourPlan;
    final teacher = Provider.of<AppState>(context, listen: false).userType == UserType.teacher;
    if (lastIndex != null && lastIndex > 0 && stdata.altSelectedClassNames.length > lastIndex - 1) {
      selected = (lastIndex, stdata.altSelectedClassNames[lastIndex - 1]);
    } else {
      selected = (0, teacher ? stdata.selectedTeacherName! : stdata.selectedClassName!);
    }
    stdata.addListener(stdataListener);
    super.initState();
  }

  @override
  void dispose() {
    // globalen Context verwenden, weil lokaler Context hier nicht mehr sicher verwendet werden kann
    Provider.of<StuPlanData>(globalScaffoldContext, listen: false).removeListener(stdataListener);
    super.dispose();
  }
}

/// den aktuell ausgewählten Plan bearbeiten: Klasse ändern, ausgewählte Fächer/Kurse anpassen
void yourStuPlanEditAction() {
  final ypState = yourPlanPageKey.currentState;
  if (ypState == null) return;

  if (ypState.selected.$1 == 0) {
    final state = Provider.of<AppState>(globalScaffoldContext, listen: false);
    state.infoScreen ??= (state.userType != UserType.teacher)
        ? stuPlanPupilIntroScreens()
        : stuPlanTeacherIntroScreens();
  } else {
    showDialog(
      context: globalScaffoldContext,
      builder: (_) => AddNewStuPlanDialog(editId: ypState.selected.$1 - 1),
    );
  }
}

void yourStuPlanRefreshAction() {
  yourPlanDisplayKey.currentState?.forceRefreshData();
}

void yourStuPlanJumpToStartAction() {
  yourPlanDisplayKey.currentState?.jumpToStartDate();
}

const stuPlanInfoKey = "stu_plan_info";

/// Dialog beim ersten Öffnen einer Stundenplanansicht aus dem Drawer anzeigen, falls noch nicht angezeigt
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

// TODO: Dialog-Funktionen verschieben -> werden nur in plan_display.dart verwendet

// TODO: Dialoge stattdessen als Popup-Panels von unten erstellen

/// Dialog mit mehr Infos zu einer Stunde erstellen
Widget generateLessonInfoDialog(BuildContext context, VPLesson lesson, VPCSubjectS? subject, String? classNameToReplace, bool lastRoomUsageInDay) {
  // TODO: Knopf zum Erstellen von Event für diese Schulstunde an diesem Tag hinzufügen
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
          ),
          Flexible(
            child: Padding(
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
    actions: [
      /// Shortcut zum entsprechenden Raumplan - natürlich nur sichtbar, wenn ein Raum existiert
      /// und die betreffende Seite nicht schon der Raumplan ist - dann würde der Link
      /// auf genau diese Seite mit genau dem aktuellen Raum verweisen -> das wäre sinnlos
      /// Dabei wird immer der erste Raum von evtl. mehreren vorhandenen verwendet
      /// toString, weil es ohne seltsamerweise nicht funktioniert hat
      if (lesson.roomCodes.isNotEmpty
          && ((Provider.of<AppState>(context, listen: false).selectedNavPageIDs).toString() != [StuPlanPageIDs.main, StuPlanPageIDs.roomPlans].toString())
          && Provider.of<Preferences>(context, listen: false).stuPlanShowRoomPlanLink
      )
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Provider.of<InternalState>(context, listen: false).lastSelectedRoomPlan = lesson.roomCodes.first;
            Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.roomPlans];
          },
          child: const Text("Zum Raumplan"),
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
                    WidgetSpan(child: Icon(MdiIcons.clock, color: Colors.grey)),
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
                    WidgetSpan(child: Icon(MdiIcons.timelineClock, color: Colors.grey)),
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
                    WidgetSpan(child: Icon(MdiIcons.clockStart, color: Colors.grey)),
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
                    WidgetSpan(child: Icon(MdiIcons.accountGroup, color: Colors.grey)),
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
                    WidgetSpan(child: Icon(MdiIcons.humanMaleBoard, color: Colors.grey)),
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
                    WidgetSpan(child: Icon(MdiIcons.informationOutline, color: Colors.grey)),
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
