
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
    return Consumer4<StuPlanData, AppState, CredentialStore, Preferences>(
      builder: (context, stdata, state, creds, prefs, _) {
        final sie = prefs.preferredPronoun == Pronoun.sie;
        final user = state.userType;
        return Card(
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
                        "${shouldGoToNextPlanDay(context) ? "Morgige" : "Heutige"} Vertretungen",
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              if (!shouldShowStuPlanIntro(stdata, user == UserType.teacher)) SizedBox(
                height: 200,
                child: ScrollConfiguration( // TODO: propagate scroll event to upper scroll view if this view couldn't scroll
                  behavior: const ScrollBehavior().copyWith(overscroll: false),
                  child: (user == UserType.pupil || user == UserType.parent) ? FutureBuilder(
                    future: (creds.vpPassword != null) ? IndiwareDataManager.getKlDataForDate(
                      shouldGoToNextPlanDay(context)
                          ? DateTime.now().add(const Duration(days: 1))
                          : DateTime.now(),
                      creds.vpUser!,
                      creds.vpPassword!,
                      forceRefresh: forceRefresh ?? false,
                    ) : Future<(VPKlData?, bool)>.error("welp"),
                    initialData: null,
                    builder: (context, datasn) {
                      forceRefresh = false;
                      if (datasn.error != null) {
                        return const Text("Fehler beim Laden der Daten.");
                      }
                      final dataP = datasn.data;
                      final lessons = dataP?.$1?.classes.cast<VPClass?>().firstWhere((cl) => cl!.className == stdata.selectedClassName, orElse: () => null)
                        ?.lessons.where((l) => l.roomChanged || l.subjectChanged || l.teacherChanged || l.infoText != "")
                        .where((e) => stdata.selectedCourseIDs.contains(e.subjectID)).toList();
                      final considerIt = prefs.considerLernSaxTasksAsCancellation;
                      return SPWidgetList(
                        stillLoading: datasn.connectionState != ConnectionState.done,
                        lessons: lessons?.map((lesson) => considerLernSaxCancellationForLesson(lesson, considerIt)).toList(),
                        onRefresh: () => setState(() => forceRefresh = true),
                        isOnline: dataP?.$2 ?? false,
                      );
                    }
                  ) : (user == UserType.teacher) ? FutureBuilder(
                    future: IndiwareDataManager.getLeDataForDate(DateTime.now(), creds.vpUser!, creds.vpPassword!, forceRefresh: forceRefresh ?? false),
                    initialData: null,
                    builder: (context, datasn) {
                      forceRefresh = false;
                      if (datasn.error != null) {
                        return const Text("Fehler beim Laden der Daten.");
                      }
                      final data = datasn.data;
                      return SPWidgetList(
                        stillLoading: datasn.connectionState != ConnectionState.done,
                        lessons: data?.$1?.teachers.firstWhere((t) => t.teacherCode == stdata.selectedTeacherName)
                          .lessons.where((l) => l.roomChanged || l.subjectChanged || l.teachingClassChanged || l.infoText != "").toList(),
                        onRefresh: () => setState(() => forceRefresh = true),
                        isOnline: data?.$2 ?? false,
                      );
                    },
                  ) : const Text("Nicht angemeldet."),
                ),
              ) else Padding(
                padding: const EdgeInsets.only(top: 0, left: 8, right: 8, bottom: 8),
                child: SPListContainer(
                  color: colorWithLightness(keplerColorOrange.withOpacity(.75), hasDarkTheme(context) ? .025 : .9),
                  shadow: false,
                  padding: EdgeInsets.zero,
                  showBorder: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          "${sie ? "Sie haben" : "Du hast"} den Stundenplan noch nicht eingerichtet.",
                          textAlign: TextAlign.center,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ElevatedButton(
                            onPressed: () => stuPlanOnTryOpenCallback(context),
                            child: const Text("Jetzt einrichten"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SPWidgetList extends StatelessWidget {
  final List<VPLesson>? lessons;
  final VoidCallback? onRefresh;
  final bool stillLoading;
  final bool isOnline;
  const SPWidgetList({super.key, required this.lessons, this.onRefresh, this.stillLoading = false, this.isOnline = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 0, left: 8, right: 8, bottom: 8),
      child: SPListContainer(
        color: colorWithLightness(keplerColorOrange.withOpacity(.75), hasDarkTheme(context) ? .025 : .9),
        shadow: false,
        padding: EdgeInsets.zero,
        showBorder: false,
        child: () {
          Widget? child;
          if (evrydayIsSaturday() && !shouldGoToNextPlanDay(context)) {
            child = const Expanded(
              child: Center(
                child: Text(
                  "Heute ist Wochenende! 😃",
                  style: TextStyle(fontSize: 17),
                ),
              ),
            );
          } else if (stillLoading) {
            child = const Expanded(
              child: Center(
                child: Text(
                  "Lädt Vertretungen...",
                  style: TextStyle(fontSize: 17),
                ),
              ),
            );
          } else if (lessons == null) {
            child = Expanded(
              child: Center(
                child: Text(
                  isOnline ? "Keine Daten verfügbar." : "Keine Verbindung zum Server.",
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            );
          } else if (lessons!.isEmpty) {
            child = Expanded(
              child: Center(
                child: Text(
                  "${shouldGoToNextPlanDay(context) ? "Morgen" : "Heute"} keine Vertretungen.",
                  style: const TextStyle(fontSize: 17),
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
                      IconButton(
                        onPressed: (evrydayIsSaturday() && !shouldGoToNextPlanDay(context)) ? null : onRefresh,
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
                      primary: false,
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
