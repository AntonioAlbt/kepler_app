import 'package:flutter/material.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:provider/provider.dart';

InfoScreenDisplay stuPlanPupilIntroScreens() => InfoScreenDisplay(
  infoScreens: const [
    InfoScreen(
      infoTitle: Text("Klassenauswahl"),
      infoText: ClassSelectScreen(),
      closeable: true,
    ),
    InfoScreen(
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
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 32),
                          child: Text(e.contains("-") ? "Klasse $e" : "Jahrgang $e"),
                        ),
                      ))
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
  @override
  Widget build(BuildContext context) {
    return Selector<Preferences, bool>(
      selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
      builder: (context, sie, _) => Consumer<StuPlanData>(
        builder: (context, stdata, _) => Column(
          children: [
            Text("Bitte ${sie ? "wählen Sie" : "wähle"} alle Fächer, die ${sie ? "Sie belegen" : "du hast"}, aus."),
            ListView(
              shrinkWrap: true,
              children: stdata.availableSubjects[stdata.selectedClassName!]!
                .map(
                  (cs) => ListTile(
                    title: Text("${cs.subjectCode} (${cs.additionalDescr}) -> ${cs.teacherCode}"),
                  ),
                ).toList(),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(
                onPressed: () {
                  final state = Provider.of<AppState>(context, listen: false);
                  state.clearInfoScreen();
                  state.selectedNavPageIDs = [StuPlanPageIDs.main];
                },
                child: const Text("Zum Stundenplan"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InfoScreenDisplay stuPlanTeacherIntroScreens() => InfoScreenDisplay(
  infoScreens: const [
    InfoScreen(infoText: Text("is being implemented"), closeable: true,)
  ],
);
