// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2023-2025 Antonio Albert

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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/rainbow.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';
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

class YourPlanPageState extends State<YourPlanPage> with WidgetsBindingObserver {
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
                                        stdata.updateWidgets(context.read<AppState>().userType == UserType.teacher);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadWidgetData(context.read<AppState>().userType == UserType.teacher);
    }
  }

  Future<bool> _loadWidgetData(bool teacher) async {
    final stdata = context.read<StuPlanData>();
    final creds = context.read<CredentialStore>();
    final plans = <List<dynamic>>[];
    if (teacher) {
      final (data, isOnline) = await IndiwareDataManager.getLeDataForDate(DateTime.now(), creds.vpHost!, creds.vpUser!, creds.vpPassword!);
      if (data == null) return false;
      plans.add([stdata.selectedTeacherName!]);
      plans[0].addAll(
        data.teachers
          .firstWhere((c) => c.teacherCode == stdata.selectedTeacherName!)
          .lessons
          .map((l) => { "schoolHour": l.schoolHour, "subject": l.subjectCode, "rooms": l.roomCodes, "teacher": l.teacherCode, "info": l.infoText, "changed": { "subject": l.subjectChanged, "rooms": l.roomChanged, "teacher": l.teacherChanged } })
      );
    }
    final names = teacher
        ? stdata.altSelectedClassNames
        : [stdata.selectedClassName, ...stdata.altSelectedClassNames];
    if (names.isNotEmpty) {
      final (data, isOnline) = await IndiwareDataManager.getKlDataForDate(DateTime.now(), creds.vpHost!, creds.vpUser!, creds.vpPassword!);
      if (data == null) return false;
      for (int i = 0; i < names.length; i++) {
        final name = names[i];
        plans.add([name!]);
        final lessons = data.classes
          .firstWhere((c) => c.className == name)
          .lessons;
        final hidden = (teacher || i >= 1) ? stdata.getAltHiddenCourseIDs(teacher ? i : i - 1) : stdata.hiddenCourseIDs;
        plans[i + (teacher ? 1 : 0)].addAll(
          lessons
            .where((t) => !hidden.any((id) => t.subjectID == id))
            .map((l) => { "schoolHour": l.schoolHour, "subject": l.subjectCode, "rooms": l.roomCodes, "teacher": l.teacherCode, "info": l.infoText, "changed": { "subject": l.subjectChanged, "rooms": l.roomChanged, "teacher": l.teacherChanged } })
        );
        if (lessons.any((l) => hidden.any((id) => id == l.subjectID)) && context.read<Preferences>().showLessonsHiddenInfo) {
          plans[i + (teacher ? 1 : 0)].add({ "hidden": true });
        }
      }
    }
    final a = await HomeWidget.saveWidgetData("data", jsonEncode({
      "date": DateFormat("dd-MM-yyyy").format(DateTime.now()),
      "holiday": stdata.checkIfHoliday(DateTime.now()),
      "plans": plans,
    }));
    final b = await stdata.updateWidgets(teacher);
    return (a ?? false) && b;
  }

  @override
  void initState() {
    super.initState();
    final stdata = Provider.of<StuPlanData>(context, listen: false);
    final lastIndex = Provider.of<InternalState>(context, listen: false).lastSelectedClassYourPlan;
    final teacher = Provider.of<AppState>(context, listen: false).userType == UserType.teacher;
    if (lastIndex != null && lastIndex > 0 && stdata.altSelectedClassNames.length > lastIndex - 1) {
      selected = (lastIndex, stdata.altSelectedClassNames[lastIndex - 1]);
    } else {
      selected = (0, teacher ? stdata.selectedTeacherName! : stdata.selectedClassName!);
    }
    stdata.addListener(stdataListener);
    _loadWidgetData(teacher);

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shBounds = context.read<StuPlanData>().guessSummerHolidayBounds();
      if (shBounds == null) return;
      final (shStart, shEnd) = shBounds;
      final lastRemYear = context.read<InternalState>().lastClassReminderYear;
      if (shEnd.year <= lastRemYear) return;

      final diff = shEnd.difference(DateTime.now());
      if (diff.inDays > 0 && diff.inDays < 7 || kDebugMode) {
        showDialog(context: context, builder: (ctx) => AlertDialog(
          title: Text("Neues Schuljahr"),
          content: Selector<Preferences, bool>(
            selector: (ctx2, prefs) => prefs.preferredPronoun == Pronoun.sie,
            builder: (_, sie, _) => Text("Bald beginnt ein neues Schuljahr. Daher ${sie ? "sollten Sie" : "solltest Du"} überprüfen, ob ${sie ? "Sie" : "Du"} weiterhin den richtigen Stundenplan mit den richtigen Fächern ${sie ? "ausgewählt haben" : "ausgewählt hast"}. Dafür wird jetzt der Auswahlbildschirm geöffnet."),
          ),
          actions: [
            TextButton(onPressed: () {
              context.read<AppState>().infoScreen ??= (context.read<AppState>().userType != UserType.teacher)
                  ? stuPlanPupilIntroScreens()
                  : stuPlanTeacherIntroScreens();
              Navigator.pop(ctx);
            }, child: Text("Okay, öffnen")),
          ],
        ));
        context.read<InternalState>().lastClassReminderYear = shEnd.year;
      }
    });
  }

  @override
  void dispose() {
    // globalen Context verwenden, weil lokaler Context hier nicht mehr sicher verwendet werden kann
    Provider.of<StuPlanData>(globalScaffoldContext, listen: false).removeListener(stdataListener);
    WidgetsBinding.instance.removeObserver(this);
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
