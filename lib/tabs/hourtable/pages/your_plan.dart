import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:provider/provider.dart';

const bool showSTDebugStuff = kDebugMode;

class YourPlanPage extends StatelessWidget {
  const YourPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stdata = Provider.of<StuPlanData>(context);
    return Column(
      children: [
        const Flexible(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: StuPlanDisplay(),
          ),
        ),
        if (showSTDebugStuff) ElevatedButton(
          onPressed: () {
            stdata.selectedClassName = null;
            stdata.selectedCourseIDs = [];
          },
          child: const Text("reset"),
        ),
      ],
    );
  }
}

class StuPlanDisplay extends StatefulWidget {
  const StuPlanDisplay({super.key});

  @override
  State<StuPlanDisplay> createState() => _StuPlanDisplayState();
}

bool isWeekend(DateTime day) => day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
bool isOrSoonWeekend(DateTime day) => isWeekend(day) || isWeekend(day.add(const Duration(days: 1)));
DateTime findNextMonday(DateTime day) {
  var nm = day;
  while (nm.weekday != DateTime.monday) {
    nm = nm.add(const Duration(days: 1));
  }
  return nm;
}
bool isOrPrevWeekend(DateTime day) => isWeekend(day) || isWeekend(day.subtract(const Duration(days: 1)));
DateTime findPrevFriday(DateTime day) {
  var nm = day;
  while (nm.weekday != DateTime.friday) {
    nm = nm.subtract(const Duration(days: 1));
  }
  return nm;
}

class _StuPlanDisplayState extends State<StuPlanDisplay> {
  final format = DateFormat("EE, dd.MM.yyyy");
  DateTime currentDate = DateTime.now();

  DateTime getStartDate() {
    final today = DateTime.now();
    if (isWeekend(today)) return findNextMonday(today);
    return today;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton.outlined(
              icon: const Icon(Icons.arrow_back),
              onPressed: (currentDate.isAfter(DateTime.now())) ? () => setState(() {
                if (isOrPrevWeekend(currentDate)) {
                  currentDate = findPrevFriday(currentDate);
                } else {
                  currentDate = currentDate.subtract(const Duration(days: 1));
                }
              }) : null,
            ),
            // IconButton(
            //   icon: const Icon(Icons.fast_rewind),
            //   onPressed: (currentDate.isAfter(DateTime.now())) ? () => setState(() {
            //     currentDate = DateTime.now();
            //   }) : null,
            // ),
            Expanded(
              child: Text(
                format.format(currentDate),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            // IconButton(
            //   icon: const Icon(Icons.fast_forward),
            //   onPressed: (currentDate.isBefore(getStartDate().add(const Duration(days: 13)))) ? () => setState(() {
            //     currentDate = getStartDate().add(const Duration(days: 14));
            //   }) : null,
            // ),
            IconButton.outlined(
              icon: const Icon(Icons.arrow_forward),
              onPressed: (currentDate.isBefore(getStartDate().add(const Duration(days: 13)))) ? () => setState(() {
                if (isOrSoonWeekend(currentDate)) {
                  currentDate = findNextMonday(currentDate);
                } else {
                  currentDate = currentDate.add(const Duration(days: 1));
                }
              }) : null,
            ),
          ],
        ),
        Flexible(
          child: StuPlanDayDisplay(
            date: currentDate,
            key: ValueKey(currentDate),
          ),
        ),
      ],
    );
  }
}

class StuPlanDayDisplay extends StatefulWidget {
  final DateTime date;
  const StuPlanDayDisplay({super.key, required this.date});

  @override
  State<StuPlanDayDisplay> createState() => _StuPlanDayDisplayState();
}

class _StuPlanDayDisplayState extends State<StuPlanDayDisplay> {
  bool _loading = true;
  List<VPLesson>? lessons;
  String? lastUpdated;
  List<String>? additionalInfo;
  List<VPTeacherSupervision>? supervisions;
  Bw fromCache = Bw(null);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            Text("Lädt Stundenplan für ${DateFormat.yMd().format(widget.date)}...")
          ],
        ),
      );
    }
    return Column(
      children: [
        Text("zuletzt aktualisiert: ${lastUpdated ?? "unbekannt"}"),
        if (showSTDebugStuff) Text("fetched ${fromCache.val == null ? "from somewhere?" : fromCache.val == true ? "from cache" : "from the internet"}"),
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                // color: (isDarkMode(context)) ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                // border: Border.all(
                //   color: Colors.grey.shade700,
                // ),
                color: Theme.of(context).colorScheme.background,
                boxShadow: [
                  BoxShadow(
                    color: hasDarkTheme(context) ? Colors.black45 : Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: (){
                if (lessons == null) {
                  return const Center(
                    child: Text("Keine Daten verfügbar."),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: ListView.separated(
                    itemCount: lessons!.length,
                    itemBuilder: (context, index) => LessonDisplay(lessons![index], index > 0 ? lessons!.elementAtOrNull(index - 1)?.schoolHour : null),
                    separatorBuilder: (context, index) => const Divider(height: 24),
                  ),
                );
              }()
            ),
          ),
        ),
        if (additionalInfo != null) Flexible(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              decoration: BoxDecoration(
                // border: Border.all(
                //   color: Colors.grey.shade800
                // ),
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.background,
                boxShadow: [
                  BoxShadow(
                    color: hasDarkTheme(context) ? Colors.black26 : Colors.grey.withOpacity(0.24),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: additionalInfo?.length ?? 1,
                  itemBuilder: (context, index) => Text(additionalInfo![index]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    _loadData();
    super.initState();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final state = Provider.of<AppState>(context, listen: false);
    final user = state.userType;
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final stdata = Provider.of<StuPlanData>(context, listen: false);
    if (creds.vpUser == null || creds.vpPassword == null) {
      state.selectedNavPageIDs = [PageIDs.home];
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fehler bei der Datenabfrage. Bitte erneut anmelden."),
        ),
      );
      return;
    }
    if (user == UserType.pupil || user == UserType.parent) {
      final klData = await IndiwareDataManager.getKlDataForDate(
        widget.date,
        creds.vpUser!,
        creds.vpPassword!,
        fromCache: fromCache,
      );
      lastUpdated = klData?.header.lastUpdated;
      lessons = klData?.classes.cast<VPClass?>()
          .firstWhere((cl) => cl?.className == stdata.selectedClassName!,
              orElse: () => null)?.lessons
              .where((element) => stdata.selectedCourseIDs.contains(element.subjectID)).toList();
      additionalInfo = klData?.additionalInfo;
    } else if (user == UserType.teacher) {
      final leData = await IndiwareDataManager.getLeDataForDate(
        widget.date,
        creds.vpUser!,
        creds.vpPassword!,
        fromCache: fromCache,
      );
      lastUpdated = leData?.header.lastUpdated;
      final teacher = leData
          ?.teacher.cast<VPTeacher?>()
          .firstWhere((cl) => cl?.teacherCode == stdata.selectedTeacherName!,
              orElse: () => null);
      lessons = teacher?.lessons;
      supervisions = teacher?.supervisions;
      additionalInfo = leData?.additionalInfo;
    }
    lessons?.sort((l1, l2) {
      final t1 = l1.schoolHour.compareTo(l2.schoolHour);
      if (t1 != 0) return t1;
      return l1.subjectCode.compareTo(l2.subjectCode);
    });
    setState(() => _loading = false);
  }
}

class LessonDisplay extends StatelessWidget {
  final VPLesson lesson;
  final int? previousLessonHour;
  const LessonDisplay(this.lesson, this.previousLessonHour, {super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontSize: 18,
        height: 0,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 25,
                child: (previousLessonHour != lesson.schoolHour) ? Text("${lesson.schoolHour}. ") : const SizedBox.shrink(),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  lesson.subjectCode,
                  style: TextStyle(
                    color: (lesson.subjectChanged) ? Colors.red : null,
                    fontWeight: (lesson.subjectChanged) ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              if (lesson.teacherCode != "")
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    lesson.teacherCode,
                    style: TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      fontWeight: (lesson.teacherChanged) ? FontWeight.bold : null,
                      color: (lesson.teacherChanged) ? Colors.red : null,
                    ),
                  ),
                ),
              const Spacer(),
              Text(lesson.roomNr),
            ],
          ),
          if (lesson.subjectChanged || lesson.teacherChanged) Consumer<StuPlanData>(
            builder: (context, stdata, child) {
              final originalSubj = stdata.availableClassSubjects!.cast<VPCSubjectS?>().firstWhere((s) => s!.subjectID == lesson.subjectID);
              if (originalSubj == null || lesson.infoText.toLowerCase().startsWith(originalSubj.subjectCode.toLowerCase())) return const SizedBox.shrink();
              return DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 15,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 25),
                    const Text("statt"),
                    if (lesson.subjectChanged) Text(" ${originalSubj.subjectCode}"),
                    if (lesson.teacherChanged) Text(" bei ${originalSubj.teacherCode}"),
                  ],
                ),
              );
            },
          ),
          if (lesson.infoText != "") Row(
            children: [
              const SizedBox(width: 25),
              Text(
                lesson.infoText,
                style: const TextStyle(
                  fontSize: 15
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void yourStuPlanEditAction() {
  final state = Provider.of<AppState>(globalScaffoldKey.currentContext!, listen: false);
  state.infoScreen ??= (state.userType != UserType.teacher)
      ? stuPlanPupilIntroScreens()
      : stuPlanTeacherIntroScreens();
}
