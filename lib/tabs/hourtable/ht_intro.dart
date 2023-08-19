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
  const ClassSelectScreen({super.key});

  @override
  State<ClassSelectScreen> createState() => _ClassSelectScreenState();
}

DropdownMenuItem<String> classNameToDropdownItem(String className)
  => DropdownMenuItem(
      value: className,
      child: Padding(
        padding: const EdgeInsets.only(right: 32),
        child: Text(className.contains("-") ? "Klasse $className" : "Jahrgang $className"),
      ),
    );

class _ClassSelectScreenState extends State<ClassSelectScreen> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Selector<Preferences, bool>(
      selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
      builder: (context, sie, _) => Consumer<StuPlanData>(
        builder: (context, stdata, _) => Column(
          children: [
            Text("Bitte ${sie ? "wählen Sie Ihre" : "wähle Deine"} Klasse für den Stundenplan aus."),
            if (_loading) const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ) else DropdownButton(
              items: stdata.availableClasses
                  .map((e) => classNameToDropdownItem(e))
                  .toList(),
              value: stdata.selectedClassName ?? stdata.availableClasses.first,
              onChanged: (value) => stdata.selectedClassName = value,
              iconSize: 24,
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(
                onPressed: () => infoScreenState.next(),
                child: const Text("Weiter zur Fachwahl"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    final creds = Provider.of<CredentialStore>(context, listen: false);
    setState(() => _loading = true);
    getKlassenXml(creds.vpUser!, creds.vpPassword!).then(
      (value) {
        final spdata = Provider.of<StuPlanData>(context, listen: false);
        spdata.loadDataFromKlData(value);
        spdata.selectedClassName ??= spdata.availableClasses.first;
        setState(() => _loading = false);
      },
    );
    super.initState();
  }
}

class SubjectSelectScreen extends StatefulWidget {
  const SubjectSelectScreen({super.key});

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
            if (user == UserType.pupil) Text("Bitte ${sie ? "wählen Sie" : "wähle"} alle Fächer und AGs, die ${sie ? "Sie belegen" : "Du hast bzw. belegst"}, aus."),
            if (user == UserType.parent) Text("Bitte ${sie ? "wählen Sie" : "wähle"} alle Fächer und AGs, die ${sie ? "Ihr" : "Dein"} Kind belegt."),
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
  infoScreens: const [
    InfoScreen(infoText: Text("is being implemented"), closeable: true,)
  ],
);
