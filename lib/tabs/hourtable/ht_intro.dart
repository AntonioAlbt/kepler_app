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
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:provider/provider.dart';

InfoScreenDisplay stuPlanPupilIntroScreens() => InfoScreenDisplay(
  infoScreens: [
    InfoScreen(
      infoTitle: const Text("Klassenauswahl"),
      infoText: const ClassSelectScreen(),
      onTryClose: (_, context) {
        if (globalScaffoldState.isDrawerOpen) globalScaffoldState.closeDrawer();
        return true;
      },
      closeable: true,
    ),
    const InfoScreen(
      infoTitle: Text("Fachwahl"),
      infoText: SubjectSelectScreen(),
      closeable: false,
    ),
  ],
);

class ClassSelectScreen extends StatelessWidget {
  final bool teacherMode;
  const ClassSelectScreen({super.key, this.teacherMode = false});

  @override
  Widget build(BuildContext context) {
    return SPClassSelector(
      onSubmit: (selected) {
        Provider.of<StuPlanData>(context, listen: false).selectedClassName = selected;
        if (teacherMode) {
          final state = Provider.of<AppState>(context, listen: false);
          state.clearInfoScreen();
          if (globalScaffoldState.isDrawerOpen) globalScaffoldState.closeDrawer();
          state.selectedNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
        } else {
          infoScreenState.next();
        }
      },
      teacherMode: teacherMode,
    );
  }
}

DropdownMenuItem<String> classNameToDropdownItem(String className, bool teacher)
  => DropdownMenuItem(
      value: className,
      child: Padding(
        padding: const EdgeInsets.only(right: 32),
        child: Text(teacher ? className : className.contains("-") ? "Klasse $className" : "Jahrgang $className"),
      ),
    );

String? _previousSelectedClass;

class SPClassSelector extends StatefulWidget {
  final bool teacherMode;
  final void Function(String selected) onSubmit;
  final void Function()? onCancel;

  const SPClassSelector({super.key, required this.teacherMode, required this.onSubmit, this.onCancel});

  @override
  State<SPClassSelector> createState() => _SPClassSelectorState();
}

class _SPClassSelectorState extends State<SPClassSelector> {
  bool _loading = true;
  String? _error;
  String? selected;

  @override
  Widget build(BuildContext context) {
    final userType = Provider.of<AppState>(globalScaffoldContext, listen: false).userType;
    final sie = Provider.of<Preferences>(globalScaffoldContext, listen: false).preferredPronoun == Pronoun.sie;
    final stdata = Provider.of<StuPlanData>(globalScaffoldContext, listen: false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (userType == UserType.pupil) Text("Bitte ${sie ? "wählen Sie Ihre" : "wähle Deine"} Klasse für den Stundenplan aus.")
        else if (userType == UserType.parent) Text("Bitte ${sie ? "wählen Sie" : "wähle"} die Klasse ${sie ? "Ihres" : "Deines"} Kindes für den Stundenplan aus.")
        else if (userType == UserType.teacher) Text("Bitte ${sie ? "wählen Sie Ihr" : "wähle Dein"} Lehrerkürzel aus."),
        if (_loading) const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        ) else if (_error != null) Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text("Erneut versuchen"),
              ),
            ],
          ),
        ) else AnimatedBuilder(
          animation: stdata,
          builder: (context, _) => DropdownButton(
            items: (widget.teacherMode ? stdata.availableTeachers : stdata.availableClasses)!
                .map((e) => classNameToDropdownItem(e, widget.teacherMode))
                .toList(),
            value: selected,
            onChanged: (value) => setState(() => selected = value),
            iconSize: 24,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 8, left: 8, right: 8, bottom: widget.onCancel != null ? 0 : 8),
          child: ElevatedButton(
            onPressed: (_error == null) ? () => widget.onSubmit(selected ?? stdata.availableClasses?.firstOrNull ?? "JG12") : null,
            child: (widget.teacherMode) ? const Text("Zum Stundenplan") : const Text("Weiter zur Fachwahl"),
          ),
        ),
        if (widget.onCancel != null) Padding(
          padding: const EdgeInsets.only(top: 0, left: 8, right: 8, bottom: 8),
          child: TextButton(
            onPressed: widget.onCancel,
            child: const Text("Abbrechen"),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    _loadData().then(
      (stdata) {
        if (stdata == null) return;
        if (!widget.teacherMode && stdata.selectedClassName != null) {
          selected = stdata.selectedClassName!;
        } else if (widget.teacherMode && stdata.selectedTeacherName != null) {
          selected = stdata.selectedTeacherName!;
        }
        selected = widget.teacherMode ? stdata.availableTeachers!.first : stdata.availableClasses!.first;
      },
    );
    super.initState();

    _previousSelectedClass = Provider.of<StuPlanData>(globalScaffoldContext, listen: false).selectedClassName;
  }

  Future<StuPlanData?> _loadData() async {
    final creds = Provider.of<CredentialStore>(globalScaffoldContext, listen: false);
    final spdata = Provider.of<StuPlanData>(globalScaffoldContext, listen: false);
    setState(() {
      _loading = true;
      _error = null;
    });
    if (creds.lernSaxLogin == lernSaxDemoModeMail) {
      await Future.delayed(const Duration(milliseconds: 100)); // not elegant, but avoids state change conflicts
      spdata.loadDataFromKlData(
        VPKlData(
          header: const VPHeader(lastUpdated: "Datum", dataDate: "", filename: "Plan2022202.xml"),
          holidays: const VPHolidays(holidayDateStrings: ["240105"]),
          classes: [
            VPClass(
              className: "Demo",
              hourBlocks: [VPHourBlock(startTime: HMTime(10, 00), endTime: HMTime(12, 00), blockStartLesson: 1)],
              courses: [
                const VPClassCourse(teacherCode: "Sei", courseName: "Info"),
                const VPClassCourse(teacherCode: "Hal", courseName: "Ph"),
                const VPClassCourse(teacherCode: "Jul", courseName: "Ma"),
              ],
              subjects: [
                const VPClassSubject(teacherCode: "Sei", subjectCode: "Info", subjectID: 1),
                const VPClassSubject(teacherCode: "Hal", subjectCode: "Ph", subjectID: 2),
                const VPClassSubject(teacherCode: "Jul", subjectCode: "Ma", subjectID: 3),
              ],
              lessons: [
                VPLesson(
                  schoolHour: 1,
                  startTime: HMTime(7, 35),
                  endTime: HMTime(8, 20),
                  subjectCode: "De",
                  subjectChanged: true,
                  teacherCode: "Kol",
                  teacherChanged: true,
                  roomCodes: ["404"],
                  roomChanged: false,
                  subjectID: 3,
                  infoText: "Mathe fällt aus",
                ),
                VPLesson(
                  schoolHour: 2,
                  startTime: HMTime(8, 30),
                  endTime: HMTime(9, 15),
                  subjectCode: "Info",
                  subjectChanged: false,
                  teacherCode: "Sei",
                  teacherChanged: false,
                  roomCodes: ["202"],
                  roomChanged: false,
                  subjectID: 1,
                  infoText: "",
                ),
                VPLesson(
                  schoolHour: 3,
                  startTime: HMTime(9, 15),
                  endTime: HMTime(10, 0),
                  subjectCode: "Info",
                  subjectChanged: false,
                  teacherCode: "Sei",
                  teacherChanged: false,
                  roomCodes: ["202"],
                  roomChanged: false,
                  subjectID: 1,
                  infoText: "",
                ),
                VPLesson(
                  schoolHour: 4,
                  startTime: HMTime(10, 30),
                  endTime: HMTime(11, 15),
                  subjectCode: "Ph",
                  subjectChanged: false,
                  teacherCode: "Hej",
                  teacherChanged: true,
                  roomCodes: ["115"],
                  roomChanged: true,
                  subjectID: 2,
                  infoText: "",
                ),
                VPLesson(
                  schoolHour: 5,
                  startTime: HMTime(11, 15),
                  endTime: HMTime(12, 00),
                  subjectCode: "Ph",
                  subjectChanged: false,
                  teacherCode: "Hej",
                  teacherChanged: true,
                  roomCodes: ["115"],
                  roomChanged: true,
                  subjectID: 2,
                  infoText: "",
                ),
              ],
            ),
          ],
          additionalInfo: [
            "Dies ist eine Demo.",
            "Hier wären Infos zur Schule.",
          ],
        ),
      );
      spdata.selectedClassName ??= spdata.availableClasses!.first;
      setState(() {
        _loading = false;
        _error = null;
      });
      return spdata;
    }
    if (widget.teacherMode) {
      try {
        if (creds.vpHost == null || creds.vpUser == null || creds.vpPassword == null) {
          final (online, lsdata) = await getLernSaxAppDataJson(creds.lernSaxLogin!, creds.lernSaxToken!, widget.teacherMode);
          if (!online || lsdata == null) throw Exception("error when loading data from lernsax${!online ? " (not online)" : ""}");
          creds.vpHost = lsdata.host;
          creds.vpUser = lsdata.user;
          creds.vpPassword = lsdata.password;
        }
        final (data, online) = await getLehrerXmlLeData(creds.vpHost!, creds.vpUser!, creds.vpPassword!);
        if (data == null) {
          setState(() {
            _error = online ? "Fehler bei der Abfrage der Lehrer. Bitte später erneut probieren." : "Fehler bei der Verbindung zum Server. Ist Internet vorhanden?";
            _loading = false;
          });
          return null;
        }
        spdata.loadDataFromLeData(data);
        spdata.selectedTeacherName ??= spdata.availableTeachers!.first;
        setState(() => _loading = false);
        return spdata;
      } catch (e, s) {
        logCatch("ht-intro", e, s);
        setState(() {
          _error = "Fehler bei der Abfrage der Lehrer. Bitte später erneut probieren.";
          _loading = false;
        });
      }
    } else {
      try {
        final (data, online) = await getKlassenXmlKlData(creds.vpHost!, creds.vpUser!, creds.vpPassword!);
        if (data == null) {
          setState(() {
            _loading = false;
            _error = online ? "Fehler bei der Abfrage der Lehrer. Bitte später erneut probieren." : "Fehler bei der Verbindung zum Server. Ist Internet vorhanden?";
          });
          return null;
        }
        spdata.loadDataFromKlData(data);
        spdata.selectedClassName ??= spdata.availableClasses!.first;
        setState(() => _loading = false);
        return spdata;
      } catch (e, s) {
        logCatch("ht-intro", e, s);
        setState(() {
          _loading = false;
          _error = "Fehler bei der Abfrage der Klassen. Bitte später erneut probieren.";
        });
      }
    }
    return null;
  }
}

class SubjectSelectScreen extends StatelessWidget {
  const SubjectSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StuPlanData>(
      builder: (context, stdata, _) {
        return SPSubjectSelector(
          onGoBack: () {
            infoScreenState.previous();
          },
          onFinish: (selected) {
            Provider.of<StuPlanData>(context, listen: false).selectedCourseIDs = selected;
            final state = Provider.of<AppState>(context, listen: false);
            state.clearInfoScreen();
            if (globalScaffoldState.isDrawerOpen) globalScaffoldState.closeDrawer();
            state.selectedNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
          },
          availableSubjects: stdata.availableClassSubjects!,
          currentShowExams: stdata.selectedClassName != null && !stdata.selectedClassName!.contains("-"),
          onShowExams: (val) {
            Provider.of<Preferences>(context, listen: false).stuPlanShowExams = val;
          },
        );
      }
    );
  }
}

class SPSubjectSelector extends StatefulWidget {
  final void Function(List<int> subjectIDs) onFinish;
  final void Function() onGoBack;
  final void Function(bool enabled)? onShowExams;
  final List<VPCSubjectS> availableSubjects;
  final bool currentShowExams;

  const SPSubjectSelector({super.key, required this.onFinish, required this.onGoBack, this.onShowExams, required this.availableSubjects, this.currentShowExams = false});

  @override
  State<SPSubjectSelector> createState() => _SPSubjectSelectorState();
}

class _SPSubjectSelectorState extends State<SPSubjectSelector> {
  late final ScrollController _scctr;
  final List<int> _selected = [];
  bool _showExams = false;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppState>(globalScaffoldContext, listen: false).userType;
    final sie = Provider.of<Preferences>(globalScaffoldContext, listen: false).preferredPronoun == Pronoun.sie;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (user == UserType.pupil) Text("Bitte ${sie ? "wählen Sie" : "wähle"} alle Fächer und AGs, die ${sie ? "Sie belegen" : "Du hast bzw. belegst"}, aus.")
        else if (user == UserType.parent) Text("Bitte ${sie ? "wählen Sie" : "wähle"} alle Fächer und AGs, die ${sie ? "Ihr" : "Dein"} Kind belegt.")
        else if (user == UserType.teacher) Text("Bitte ${sie ? "wählen Sie" : "wähle"} alle Fächer und AGs, ${sie ? "Ihnen" : "Dir"} angezeigt werden sollen."),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () {
                  for (var e in widget.availableSubjects) {
                    _selected.add(e.subjectID);
                  }
                  setState(() {});
                },
                child: const Text("Alle anwählen"),
              ),
            ),
            TextButton(
              onPressed: () {
                for (var e in widget.availableSubjects) {
                  _selected.remove(e.subjectID);
                }
                setState(() {});
              },
              child: const Text("Alle abwählen"),
            ),
          ],
        ),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * .5,
          child: SingleChildScrollView(
            controller: _scctr,
            child: Column(
              children: (){
                final list = widget.availableSubjects;
                list.sort((s1, s2) => "${s1.subjectCode}${s1.additionalDescr ?? ""}".compareTo("${s2.subjectCode}${s2.additionalDescr ?? ""}"));
                return list;
              }()
                .map((subject) => GestureDetector(
                  onTap: () {
                    if (_selected.contains(subject.subjectID)) {
                      _selected.remove(subject.subjectID);
                    } else {
                      _selected.add(subject.subjectID);
                    }
                    setState(() {});
                  },
                  child: Row(
                    children: [
                      Checkbox(
                        visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
                        value: _selected.contains(subject.subjectID),
                        onChanged: (val) {
                          if (val == true) {
                            _selected.add(subject.subjectID);
                          } else {
                            _selected.remove(subject.subjectID);
                          }
                          setState(() {});
                        },
                      ),
                      Text(subject.subjectCode),
                      if (subject.additionalDescr != null)
                        Text(
                          " (${subject.additionalDescr})",
                          style: TextStyle(
                            color: (hasDarkTheme(context))
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      Text(" - ${subject.teacherCode}"),
                    ],
                  ),
                )).toList(),
            ),
          ),
        ),
        if (widget.onShowExams != null) CheckboxListTile.adaptive(
          value: _showExams,
          onChanged: (val) {
            widget.onShowExams!(val!);
            setState(() {
              _showExams = val;
            });
          },
          title: const Text("Infos zu Klausuren anzeigen"),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: widget.onGoBack,
                child: const Text("Zurück"),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ElevatedButton(
                  onPressed: () => widget.onFinish(_selected),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Abschließen"),
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _scctr = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stdata = Provider.of<StuPlanData>(globalScaffoldContext, listen: false);
      if (stdata.selectedClassName != _previousSelectedClass) {
        stdata.selectedCourseIDs = [];
        stdata.selectedCourseIDs = stdata.availableClassSubjects!.map((e) => e.subjectID).toList();
      }
      final cname = stdata.selectedClassName;
      if (cname != null) Provider.of<Preferences>(globalScaffoldContext, listen: false).stuPlanShowExams = !cname.contains("-");
    });
    _showExams = widget.currentShowExams;
  }

  @override
  void dispose() {
    super.dispose();
    _scctr.dispose();
  }
}

InfoScreenDisplay stuPlanTeacherIntroScreens() => InfoScreenDisplay(
  infoScreens: [
    InfoScreen(
      infoTitle: const Text("Lehrerauswahl"),
      infoText: const ClassSelectScreen(teacherMode: true),
      onTryClose: (_, context) {
        if (globalScaffoldState.isDrawerOpen) globalScaffoldState.closeDrawer();
        return true;
      },
      closeable: true,
    ),
  ],
);


class AddNewStuPlanDialog extends StatefulWidget {
  const AddNewStuPlanDialog({super.key});

  @override
  State<AddNewStuPlanDialog> createState() => _AddNewStuPlanDialogState();
}

class _AddNewStuPlanDialogState extends State<AddNewStuPlanDialog> {
  String? _newClass;

  @override
  Widget build(BuildContext context) {
    final stdata = Provider.of<StuPlanData>(globalScaffoldContext, listen: false);
    return AnimatedBuilder(
      animation: stdata,
      builder: (context, _) {
        return AlertDialog(
          title: const Text("Stundenplan hinzufügen"),
          content: _newClass == null ? SPClassSelector(
            teacherMode: false,
            onSubmit: (selected) {
              setState(() => _newClass = selected);
            },
            onCancel: () => Navigator.pop(context, false),
          ) : SPSubjectSelector(
            onFinish: (selected) {
              stdata.altSelectedClassNames = stdata.altSelectedClassNames..add(_newClass!);
              stdata.altSelectedCourseIDs = stdata.altSelectedCourseIDs..add(selected.join("|"));
              Navigator.pop(context, true);
            },
            onGoBack: () {
              setState(() => _newClass = null);
            },
            availableSubjects: stdata.availableSubjects[_newClass!]!,
          ),
        );
      }
    );
  }

  @override
  void initState() {
    super.initState();
  }
}
