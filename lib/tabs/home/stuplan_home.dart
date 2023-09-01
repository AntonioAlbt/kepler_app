
import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/hourtable/hourtable.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';
import 'package:provider/provider.dart';

class HomeStuPlanWidget extends StatefulWidget {
  const HomeStuPlanWidget({super.key});

  @override
  State<HomeStuPlanWidget> createState() => HomeStuPlanWidgetState();
}

// this code was written saturday at 0:30 am
/// acschually returns if today is weekend
bool evrydayIsSaturday() {
  final date = DateTime.now();
  return date.weekday == 6 || date.weekday == 7;
}

class HomeStuPlanWidgetState extends State<HomeStuPlanWidget> {
  bool? forceRefresh;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppState>(context, listen: false).userType;
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final sie = Provider.of<Preferences>(context, listen: false).preferredPronoun == Pronoun.sie;
    return Consumer<StuPlanData>(
      builder: (context, stdata, _) => Card(
        color: colorWithLightness(keplerColorOrange, hasDarkTheme(context) ? .2 : .8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Card(
                color: colorWithLightness(keplerColorOrange, hasDarkTheme(context) ? .05 : .85),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Text(
                      "Heutige Vertretungen",
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            if (!shouldShowStuPlanIntro(stdata, user == UserType.teacher)) ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(overscroll: false),
                child: (user == UserType.pupil || user == UserType.parent) ? FutureBuilder(
                  future: IndiwareDataManager.getKlDataForDate(DateTime.now(), creds.vpUser!, creds.vpPassword!, forceRefresh: forceRefresh ?? false),
                  initialData: null,
                  builder: (context, datasn) {
                    forceRefresh = false;
                    if (datasn.error != null) {
                      return const Text("Fehler beim Laden der Daten.");
                    }
                    final data = datasn.data;
                    if (datasn.connectionState != ConnectionState.done) return const CircularProgressIndicator();
                    return SPWidgetList(
                      lessons: data?.classes.cast<VPClass?>().firstWhere((cl) => cl!.className == stdata.selectedClassName, orElse: () => null)
                        ?.lessons.where((l) => l.roomChanged || l.subjectChanged || l.teacherChanged || l.infoText != "").toList(),
                      onRefresh: () => setState(() => forceRefresh = true),
                    );
                  },
                ) : (user == UserType.teacher) ? FutureBuilder(
                  future: IndiwareDataManager.getLeDataForDate(DateTime.now(), creds.vpUser!, creds.vpPassword!, forceRefresh: forceRefresh ?? false),
                  initialData: null,
                  builder: (context, datasn) {
                    forceRefresh = false;
                    if (datasn.error != null) {
                      return const Text("Fehler beim Laden der Daten.");
                    }
                    final data = datasn.data;
                    if (datasn.connectionState != ConnectionState.done) return const CircularProgressIndicator();
                    return SPWidgetList(
                      lessons: data?.teachers.firstWhere((t) => t.teacherCode == stdata.selectedTeacherName)
                        .lessons.where((l) => l.roomChanged || l.subjectChanged || l.teachingClassChanged || l.infoText != "").toList(),
                      onRefresh: () => setState(() => forceRefresh = true),
                    );
                  },
                ) : const Text("Nicht angemeldet."),
              ),
            ) else Column(
              children: [
                Text("${sie ? "Sie haben" : "Du hast"} den Stundenplan noch nicht geöffnet. Jetzt einrichten?"),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ElevatedButton(
                    onPressed: () => stuPlanOnTryOpenCallback(context),
                    child: const Text("Einrichten"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SPWidgetList extends StatelessWidget {
  final List<VPLesson>? lessons;
  final VoidCallback? onRefresh;
  const SPWidgetList({super.key, required this.lessons, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 0, left: 8, right: 8, bottom: 8),
      child: SPListContainer(
        color: colorWithLightness(keplerColorOrange.withOpacity(.75), hasDarkTheme(context) ? .025 : .9),
        shadow: false,
        padding: EdgeInsets.zero,
        blueBorder: false,
        child: () {
          final d = DateTime.now();
          Widget? child;
          if (d.weekday == 6 || d.weekday == 7) {
            child = const Expanded(
              child: Center(
                child: Text(
                  "Heute ist Wochenende! 😃",
                  style: TextStyle(fontSize: 17),
                ),
              ),
            );
          } else if (lessons == null) {
            child = const Expanded(
              child: Center(
                child: Text(
                  "Keine Daten verfügbar.",
                  style: TextStyle(fontSize: 17),
                ),
              ),
            );
          } else if (lessons!.isEmpty) {
            child = const Expanded(
              child: Center(
                child: Text(
                  "Heute keine Vertretungen.",
                  style: TextStyle(fontSize: 17),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 16, right: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
                        },
                        child: const Row(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Text(
                                "Zum Stundenplan",
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Icon(Icons.open_in_new, size: 20),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (evrydayIsSaturday()) IconButton(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh, size: 20),
                        style: IconButton.styleFrom(padding: EdgeInsets.zero, visualDensity: const VisualDensity(horizontal: -4, vertical: -4)),
                      ),
                    ],
                  ),
                ),
                Divider(
                  thickness: 1.5,
                  color: Colors.grey.shade700,
                ),
                child ?? Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12, right: 12, bottom: 8),
                    child: ListView.separated(
                      itemCount: lessons!.length,
                      itemBuilder: (context, index) => LessonDisplay(
                        lessons![index],
                        index > 0
                            ? lessons!.elementAtOrNull(index - 1)?.schoolHour
                            : null,
                      ),
                      separatorBuilder: (context, index) => const Divider(height: 24),
                    ),
                  ),
                ),
              ],
            ),
          );
        }()),
    );
  }
}