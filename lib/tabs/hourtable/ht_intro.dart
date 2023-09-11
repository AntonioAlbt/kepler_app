import 'package:flutter/material.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/indiware.dart';
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

class ClassSelectScreen extends StatefulWidget {
  final bool teacherMode;
  const ClassSelectScreen({super.key, this.teacherMode = false});

  @override
  State<ClassSelectScreen> createState() => _ClassSelectScreenState();
}

DropdownMenuItem<String> classNameToDropdownItem(String className, bool teacher)
  => DropdownMenuItem(
      value: className,
      child: Padding(
        padding: const EdgeInsets.only(right: 32),
        child: Text(teacher ? className : className.contains("-") ? "Klasse $className" : "Jahrgang $className"),
      ),
    );

class _ClassSelectScreenState extends State<ClassSelectScreen> {
  bool _loading = true;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final userType = Provider.of<AppState>(context, listen: false).userType;
    return Selector<Preferences, bool>(
      selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
      builder: (context, sie, _) => Column(
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
          ) else Consumer<StuPlanData>(
            builder: (context, stdata, _) => DropdownButton(
              items: (widget.teacherMode ? stdata.availableTeachers : stdata.availableClasses)
                  .map((e) => classNameToDropdownItem(e, widget.teacherMode))
                  .toList(),
              value: widget.teacherMode ? (stdata.selectedTeacherName ?? stdata.availableTeachers.first) : (stdata.selectedClassName ?? stdata.availableClasses.first),
              onChanged: (value) => (widget.teacherMode) ? stdata.selectedTeacherName = value : stdata.selectedClassName = value,
              iconSize: 24,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton(
              onPressed: () {
                if (widget.teacherMode) {
                  final state = Provider.of<AppState>(context, listen: false);
                  state.clearInfoScreen();
                  if (globalScaffoldState.isDrawerOpen) globalScaffoldState.closeDrawer();
                  state.selectedNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
                } else {
                  infoScreenState.next();
                }
              },
              child: (widget.teacherMode) ? const Text("Zum Stundenplan") : const Text("Weiter zur Fachwahl"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    _loadData();
    super.initState();
  }

  Future<void> _loadData() async {
    final creds = Provider.of<CredentialStore>(context, listen: false);
    setState(() {
      _loading = true;
      _error = null;
    });
    final spdata = Provider.of<StuPlanData>(context, listen: false);
    try {
      spdata.loadDataFromKlData((await getKlassenXmlKlData(creds.vpUser!, creds.vpPassword!))!);
      spdata.selectedClassName ??= spdata.availableClasses.first;
      setState(() => _loading = false);
    } catch (_) {
      setState(() {
        _loading = false;
        _error = "Fehler bei der Abfrage der Klassen. Ist Internet vorhanden?";
      });
    }
    if (widget.teacherMode) {
      try {
        spdata.loadDataFromLeData((await getLehrerXmlLeData(creds.vpUser!, creds.vpPassword!))!);
        spdata.selectedTeacherName ??= spdata.availableTeachers.first;
        setState(() => _loading = false);
      } catch (_) {
        setState(() {
          _loading = false;
          _error = "Fehler bei der Abfrage der Lehrer. Ist Internet vorhanden?";
        });
      }
    }
  }
}

class SubjectSelectScreen extends StatefulWidget {
  final bool teacherMode;
  const SubjectSelectScreen({super.key, this.teacherMode = false});

  @override
  State<SubjectSelectScreen> createState() => _SubjectSelectScreenState();
}

class _SubjectSelectScreenState extends State<SubjectSelectScreen> {
  late final ScrollController _scctr;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppState>(context, listen: false).userType;
    return Selector<Preferences, bool>(
      selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
      builder: (context, sie, _) => Consumer<StuPlanData>(
        builder: (context, stdata, _) => Column(
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
                      for (var e in stdata.availableClassSubjects!) {
                        stdata.addSelectedCourse(e.subjectID);
                      }
                    },
                    child: const Text("Alle anwählen"),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    for (var e in stdata.availableClassSubjects!) {
                      stdata.removeSelectedCourse(e.subjectID);
                    }
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
                    final list = stdata.availableClassSubjects!;
                    list.sort((s1, s2) => "${s1.subjectCode}${s1.additionalDescr ?? ""}".compareTo("${s2.subjectCode}${s2.additionalDescr ?? ""}"));
                    return list;
                  }()
                    .map((subject) => GestureDetector(
                      onTap: () {
                        if (stdata.selectedCourseIDs.contains(subject.subjectID)) {
                          stdata.removeSelectedCourse(subject.subjectID);
                        } else {
                          stdata.addSelectedCourse(subject.subjectID);
                        }
                      },
                      child: Row(
                        children: [
                          Checkbox(
                            visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
                            value: stdata.selectedCourseIDs.contains(subject.subjectID),
                            onChanged: (val) {
                              if (val == true) {
                                stdata.addSelectedCourse(subject.subjectID);
                              } else {
                                stdata.removeSelectedCourse(subject.subjectID);
                              }
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
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      infoScreenState.previous();
                    },
                    child: const Text("Zurück"),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        final state = Provider.of<AppState>(context, listen: false);
                        state.clearInfoScreen();
                        if (globalScaffoldState.isDrawerOpen) globalScaffoldState.closeDrawer();
                        state.selectedNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Zum Stundenplan"),
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
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scctr = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stdata = Provider.of<StuPlanData>(context, listen: false);
      stdata.selectedCourseIDs = [];
      stdata.selectedCourseIDs = stdata.availableClassSubjects!.map((e) => e.subjectID).toList();
    });
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
