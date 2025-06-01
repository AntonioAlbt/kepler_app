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
import 'package:kepler_app/introduction.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:provider/provider.dart';

/// Einführungsdisplays für Schüler bzw. Eltern
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
    stuPlanSetupFinishedScreen(),
  ],
);

/// Seite für Klassenauswahl
class ClassSelectScreen extends StatelessWidget {
  /// sollen Lehrerkürzel statt Klassen/JG verwendet werden und soll dann direkt zum Stundenplan weitergeleitet werden?
  final bool teacherMode;
  const ClassSelectScreen({super.key, this.teacherMode = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<StuPlanData>(
      builder: (context, stdata, _) {
        return SPClassSelector(
          preselected: teacherMode ? stdata.selectedTeacherName : stdata.selectedClassName,
          onSubmit: (selected) {
            if (teacherMode) {
              stdata.selectedTeacherName = selected;
            } else {
              stdata.selectedClassName = selected;
            }
            infoScreenState.next();
          },
          teacherMode: teacherMode,
        );
      }
    );
  }
}

/// Dropdown-Item mit Index im value entsprechend Parametern erstellen
DropdownMenuItem<(int, String)> classNameToIndexedDropdownItem(String className, bool teacher, int index, [String? suffix])
  => DropdownMenuItem(
      value: (index, className),
      child: Padding(
        padding: const EdgeInsets.only(right: 32),
        child: Text("${teacher ? className : className.contains("-") ? "Klasse $className" : "Jahrgang $className"}${suffix ?? ""}"),
      ),
    );

/// Dropdown-Item mit nur Name im value erstellen
DropdownMenuItem<String> classNameToDropdownItem(String className, bool teacher)
  => DropdownMenuItem(
      value: className,
      child: Padding(
        padding: const EdgeInsets.only(right: 32),
        child: Text(teacher ? className : className.contains("-") ? "Klasse $className" : "Jahrgang $className"),
      ),
    );

/// Widget für das Auswählen einer/eines Klasse/JGs/Lehrerkürzels
class SPClassSelector extends StatefulWidget {
  /// vorausgewählter Eintrag
  final String? preselected;
  /// Daten und Darstellung für Lehrer verwenden
  final bool teacherMode;
  /// wird nach erfolgreicher Auswahl aufgerufen
  final void Function(String selected) onSubmit;
  /// wird nach Abbruch durch Benutzer aufgerufen
  final void Function()? onCancel;
  /// Hinweis bzgl. Benachrichtigungen anzeigen
  final bool alternativeAccount;

  const SPClassSelector({super.key, this.preselected, required this.teacherMode, required this.onSubmit, this.onCancel, this.alternativeAccount = false});

  @override
  State<SPClassSelector> createState() => _SPClassSelectorState();
}

class _SPClassSelectorState extends State<SPClassSelector> {
  bool _loading = true;
  String? _error;
  String? selected;

  @override
  Widget build(BuildContext context) {
    final userType = Provider.of<AppState>(context, listen: false).userType;
    final sie = Provider.of<Preferences>(context, listen: false).preferredPronoun == Pronoun.sie;
    final stdata = Provider.of<StuPlanData>(context, listen: false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          /// Text war ursprünglich in einer Zeile, aber viel zu unübersichtlich -> aufgeteilt nach Benutzertyp
          ((userType == UserType.pupil) ? "Bitte ${sie ? "wählen Sie Ihre" : "wähle Deine"} Klasse für den Stundenplan aus."
          : (userType == UserType.parent) ? "Bitte ${sie ? "wählen Sie" : "wähle"} die Klasse ${sie ? "Ihres" : "Deines"} Kindes für den Stundenplan aus."
          : (userType == UserType.teacher) ? "Bitte ${sie ? "wählen Sie Ihr" : "wähle Dein"} Lehrerkürzel aus."
          : "") + (widget.alternativeAccount ? "\nHinweis: Nur für den primären Account werden Benachrichtigungen angezeigt." : ""),
        ),
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
          /// AnimatedBuilder eignen sich gut für ChangeNotifier, weil sie sich neu builden
          /// wenn sich etwas an animation ändert (und ein ChangeNotifier auch nur ein Listenable ist)
          /// 
          /// - hier kann vor allem nicht(!) Consumer verwendet werden, da es im aktuellen Kontext nicht unbedingt
          /// die gewünschten Provider gibt -> deshalb auch globaler Kontext an Anfang der Funktion
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
        if (widget.preselected == null) {
          selected = widget.teacherMode ? stdata.availableTeachers!.first : stdata.availableClasses!.first;
        } else {
          selected = widget.preselected;
        }
      },
    );
    super.initState();
  }

  Future<StuPlanData?> _loadData() async {
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final spdata = Provider.of<StuPlanData>(context, listen: false);
    setState(() {
      _loading = true;
      _error = null;
    });
    if (creds.lernSaxLogin == lernSaxDemoModeMail) {
      /// oha was ein schrecklicher Aufruf, aber anscheinend hab ich keine bessere Lösung gefunden
      /// (ist ja auch nur für den Demo-Modus, also eigentlich eh egal)
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
        /// weil es für Lehrer (gerade auf iOS) zeitweise das Problem gab, dass die Login-Daten für Indiware irgendwie
        /// einfach verloren gingen, frage ich sie hier nochmal komplett neu von LernSax ab
        if (creds.vpHost == null || creds.vpUser == null || creds.vpPassword == null) {
          final (online, lsdata) = await getLernSaxAppDataJson(creds.lernSaxLogin!, creds.lernSaxToken!, widget.teacherMode);
          /// da spätestens bei den "!" in getLehrerXmlLeData ein Fehler geworfen wird, wenn eins der drei null ist,
          /// kann ich bei einem Abfragefehler auch einfach hier einen werfen
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

/// für InfoScreen, Fächerauswahl für primäre ausgewählte Klasse (nur für Schüler/Eltern)
class SubjectSelectScreen extends StatelessWidget {
  const SubjectSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StuPlanData>(
      builder: (context, stdata, _) {
        return SPHiddenSubjectSelector(
          onGoBack: () {
            infoScreenState.previous();
          },
          onFinish: (hidden) {
            stdata.hiddenCourseIDs = hidden;
            context.read<StuPlanData>().updateWidgets(context.read<AppState>().userType == UserType.teacher);
            infoScreenState.next();
          },
          availableSubjects: stdata.availableClassSubjects!,
          /// wenn nicht in Klasse 5 bis 10: standardmäßig keine Klausuren anzeigen (weil Klausuren
          /// nur für Klasse 11/12 im Stundenplan stehen)
          currentShowExams: stdata.selectedClassName != null && !stdata.selectedClassName!.contains("-"),
          onShowExams: (val) {
            Provider.of<Preferences>(context, listen: false).stuPlanShowExams = val;
          },
        );
      }
    );
  }
}

/// Widget für das Auswählen von anzuzeigenden Fächern für eine Klasse
class SPHiddenSubjectSelector extends StatefulWidget {
  /// wird aufgerufen, wenn Auswahl erfolgreich abgeschlossen und auf Weiter getippt
  final void Function(List<int> hiddenSubjectIDs) onFinish;
  /// wird aufgerufen, wenn Benutzer auf "zurück" tippt
  final void Function() onGoBack;
  /// wird aufgerufen, wenn Benutzer Checkbox an- oder abwählt (Zustand ändert)
  final void Function(bool enabled)? onShowExams;
  /// Fächer, aus denen ausgewählt werden kann
  final List<VPCSubjectS> availableSubjects;
  /// Fächer, die standardmäßig nicht angewählt sein sollen
  final List<VPCSubjectS>? preDeselectedSubjects;
  /// Voreinstellung für Checkbox für Klausuren
  final bool currentShowExams;

  const SPHiddenSubjectSelector({
    super.key,
    required this.onFinish,
    required this.onGoBack,
    this.onShowExams,
    required this.availableSubjects,
    this.currentShowExams = false,
    this.preDeselectedSubjects,
  });

  @override
  State<SPHiddenSubjectSelector> createState() => _SPHiddenSubjectSelectorState();
}

class _SPHiddenSubjectSelectorState extends State<SPHiddenSubjectSelector> {
  /// warum der existiert, weiß ich nicht (vielleicht für eventuelle ScrollBar?)
  late final ScrollController _scctr;
  final List<int> _selected = [];
  final List<int> _toBeHidden = [];
  bool _showExams = false;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppState>(context, listen: false).userType;
    final sie = Provider.of<Preferences>(context, listen: false).preferredPronoun == Pronoun.sie;
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
                    _toBeHidden.remove(e.subjectID);
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
                  _toBeHidden.add(e.subjectID);
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
                      _toBeHidden.add(subject.subjectID);
                    } else {
                      _selected.add(subject.subjectID);
                      _toBeHidden.remove(subject.subjectID);
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
                            _toBeHidden.remove(subject.subjectID);
                          } else {
                            _selected.remove(subject.subjectID);
                            _toBeHidden.add(subject.subjectID);
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
          subtitle: const Text("nur für Jahrgang 11 und 12 empfohlen"),
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
                  onPressed: () => widget.onFinish(_toBeHidden),
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
    _showExams = widget.currentShowExams;
    _selected.addAll(widget.availableSubjects.map((e) => e.subjectID));
    widget.preDeselectedSubjects?.forEach((s) => _selected.remove(s.subjectID));
  }

  @override
  void dispose() {
    super.dispose();
    _scctr.dispose();
  }
}

/// Einleitungs-InfoScreens für Lehrerstundenplan (nur Auswahl Lehrerkürzel)
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
    stuPlanSetupFinishedScreen(),
  ],
);

InfoScreen stuPlanSetupFinishedScreen() => InfoScreen(
  infoImage: Icon(Icons.check),
  infoTitle: Text("Einrichtung abgeschlossen"),
  infoText: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
        child: Selector<Preferences, bool>(
          selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
          builder: (ctx, sie, _) => Text("${sie ? "Sie haben Ihren" : "Du hast Deinen"} primären Stundenplan erfolgreich eingerichtet."),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
        child: TextButton(
          onPressed: () {
            final state = Provider.of<AppState>(globalScaffoldContext, listen: false);
            state.clearInfoScreen();
            if (globalScaffoldState.isDrawerOpen) globalScaffoldState.closeDrawer();
            state.selectedNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
            showDialog(
              context: globalScaffoldContext,
              builder: (_) => const AddNewStuPlanDialog(),
            );
          },
          child: Text("Weiteren Stundenplan hinzufügen"),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: () {
            final state = Provider.of<AppState>(globalScaffoldContext, listen: false);
            state.clearInfoScreen();
            if (globalScaffoldState.isDrawerOpen) globalScaffoldState.closeDrawer();
            state.selectedNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
          },
          child: TextWithArrowForward(text: "Zum Stundenplan"),
        ),
      ),
    ],
  ),
  onTryClose: (_, context) {
    if (globalScaffoldState.isDrawerOpen) globalScaffoldState.closeDrawer();
    return true;
  },
);


/// Dialog, um Stundenplan hinzuzufügen oder zu bearbeiten(!) (wenn `editId != null`)
class AddNewStuPlanDialog extends StatefulWidget {
  /// wenn gegeben, statt neuen Stundenplan zu erstellen vorhandenen mit dieser ID
  /// (diesem Index in StuPlanData.altSelectedClassNames) bearbeiten
  final int? editId;

  const AddNewStuPlanDialog({super.key, this.editId});

  @override
  State<AddNewStuPlanDialog> createState() => _AddNewStuPlanDialogState();
}

class _AddNewStuPlanDialogState extends State<AddNewStuPlanDialog> {
  String? _newClass;

  @override
  Widget build(BuildContext context) {
    final stdata = Provider.of<StuPlanData>(context, listen: false);
    return AnimatedBuilder(
      animation: stdata,
      builder: (context, _) {
        return AlertDialog(
          title: Text("Stundenplan ${widget.editId != null ? "bearbeiten" : "hinzufügen"}"),
          content: _newClass == null ? SPClassSelector(
            preselected: widget.editId != null ? stdata.altSelectedClassNames[widget.editId!] : null,
            teacherMode: false,
            onSubmit: (selected) {
              setState(() => _newClass = selected);
            },
            onCancel: () => Navigator.pop(context, false),
            alternativeAccount: true,
          ) : SPHiddenSubjectSelector(
            onFinish: (hidden) {
              if (widget.editId == null) {
                /// da zum Benachrichtigen von Änderungen das immer neu gesetzt werden muss, wird hier eine
                /// Zuweisung verwendet, obwohl nur `add` aufgerufen wurde
                stdata.altSelectedClassNames = stdata.altSelectedClassNames..add(_newClass!);
                stdata.altHiddenCourseIDs = stdata.altHiddenCourseIDs..add(hidden.join("|"));
              } else {
                stdata.setSelectedClassForAlt(widget.editId!, _newClass!);
                stdata.setHiddenCoursesForAlt(widget.editId!, hidden);
              }
              stdata.updateWidgets(context.read<AppState>().userType == UserType.teacher);
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
