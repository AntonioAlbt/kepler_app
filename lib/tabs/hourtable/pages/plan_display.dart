import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/pages/free_rooms.dart';
import 'package:kepler_app/tabs/hourtable/pages/your_plan.dart'
    show generateLessonInfoDialog, showSTDebugStuff;
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

enum SPDisplayMode { yourPlan, classPlan, allReplaces, freeRooms, teacherPlan, roomPlan }

class StuPlanDisplay extends StatefulWidget {
  /// whatever could be selected, like the class or teacher or room
  final String selected;
  final SPDisplayMode mode;
  final bool showInfo;
  final List<String>? allRooms;
  const StuPlanDisplay(
      {super.key,
      required this.selected,
      required this.mode,
      this.showInfo = true,
      this.allRooms});

  @override
  State<StuPlanDisplay> createState() => StuPlanDisplayState();
}

bool isWeekend(DateTime day) =>
    day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
bool isOrSoonWeekend(DateTime day) =>
    isWeekend(day) || isWeekend(day.add(const Duration(days: 1)));
DateTime findNextMonday(DateTime day) {
  var nm = day;
  while (nm.weekday != DateTime.monday) {
    nm = nm.add(const Duration(days: 1));
  }
  return nm;
}

bool isOrPrevWeekend(DateTime day) =>
    isWeekend(day) || isWeekend(day.subtract(const Duration(days: 1)));
DateTime findPrevFriday(DateTime day) {
  var nm = day;
  while (nm.weekday != DateTime.friday) {
    nm = nm.subtract(const Duration(days: 1));
  }
  return nm;
}

class StuPlanDisplayState extends State<StuPlanDisplay> {
  final format = DateFormat("EE, dd.MM.");
  late DateTime currentDate;
  late DateTime startDate;
  final _ctr = StuPlanDayDisplayController();

  void forceRefreshData() {
    IndiwareDataManager.clearCachedData().then((_) => _ctr.triggerRefresh());
  }

  DateTime _getStartDate() {
    final today = DateTime.now();
    if (isWeekend(today)) return findNextMonday(today);
    return today;
  }

  @override
  void initState() {
    super.initState();
    currentDate = _getStartDate();
    startDate = _getStartDate();
  }

  @override
  void setState(VoidCallback fn) {
    _ctr.clearRefreshListeners();
    super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton.outlined(
              icon: const Icon(Icons.arrow_back),
              onPressed: (currentDate.isAfter(startDate))
                  ? () => setState(() {
                        if (isOrPrevWeekend(currentDate)) {
                          currentDate = findPrevFriday(currentDate);
                        } else {
                          currentDate =
                              currentDate.subtract(const Duration(days: 1));
                        }
                      })
                  : null,
            ),
            // IconButton(
            //   icon: const Icon(Icons.fast_rewind),
            //   onPressed: (currentDate.isAfter(DateTime.now())) ? () => setState(() {
            //     currentDate = DateTime.now();
            //   }) : null,
            // ),
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      format.format(currentDate),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  // because the max difference is 9 days (e.g. Sat -> Mon+1)
                  // only the day needs to be checked for "today"
                  if (currentDate.day == DateTime.now().day)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: hasDarkTheme(context)
                              ? colorWithLightness(keplerColorOrange, .15)
                              : colorWithLightness(keplerColorOrange, .8),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            "heute",
                            style: TextStyle(height: 0),
                          ),
                        ),
                      ),
                    ),
                ],
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
              onPressed:
                  (currentDate.isBefore(startDate.add(const Duration(days: 3))))
                      ? () => setState(() {
                            if (isOrSoonWeekend(currentDate)) {
                              currentDate = findNextMonday(currentDate);
                            } else {
                              currentDate =
                                  currentDate.add(const Duration(days: 1));
                            }
                          })
                      : null,
            ),
          ],
        ),
        Flexible(
          child: StuPlanDayDisplay(
            controller: _ctr,
            date: currentDate,
            key: ValueKey(currentDate.hashCode +
                widget.selected.hashCode +
                widget.mode.hashCode),
            selected: widget.selected,
            mode: widget.mode,
            showInfo: widget.showInfo,
            allRooms: widget.allRooms,
          ),
        ),
      ],
    );
  }
}

class StuPlanDayDisplayController {
  final List<VoidCallback> onRefreshListeners = [];

  void addRefreshListener(VoidCallback func) => onRefreshListeners.add(func);
  void clearRefreshListeners() => onRefreshListeners.clear();
  // ignore: avoid_function_literals_in_foreach_calls
  void triggerRefresh() => onRefreshListeners.forEach((func) => func());

  StuPlanDayDisplayController();
}

class StuPlanDayDisplay extends StatefulWidget {
  final DateTime date;
  final String selected;
  final StuPlanDayDisplayController? controller;
  final bool showInfo;
  final bool showSupervisions;
  final SPDisplayMode mode;
  final List<String>? allRooms;
  const StuPlanDayDisplay(
      {super.key,
      required this.date,
      required this.selected,
      required this.mode,
      this.controller,
      this.showInfo = true,
      this.showSupervisions = true,
      this.allRooms});

  @override
  State<StuPlanDayDisplay> createState() => _StuPlanDayDisplayState();
}

class _StuPlanDayDisplayState extends State<StuPlanDayDisplay> {
  bool _loading = true;
  /// gets selected lessons loaded when no special mode selected, if `freeRoomsMode` gets loaded all lessons for all classes, otherwise is null
  List<VPLesson>? lessons;
  /// only gets loaded with changed class lessons if `allReplacesMode`
  Map<String, List<VPLesson>>? changedClassLessons;
  /// gets loaded whatever mode is active
  String? lastUpdated;
  /// gets loaded when no special mode is selected
  List<String>? additionalInfo;
  /// gets loaded if the user is a teacher and no special mode is selected
  List<VPTeacherSupervision>? supervisions;
  /// is always updated when something is loaded
  Bw fromCache = Bw(null);

  List<Widget> _buildAllReplacesLessonList() {
    // final currentClass = Provider.of<StuPlanData>(context).selectedClassName;
    final children = <Widget>[];
    if (changedClassLessons == null) return [];
    changedClassLessons!.forEach((clName, lessons) {
      if (lessons.isEmpty) return;
      final cl2 = <Widget>[];
      cl2.add(Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          clName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ));
      for (var i = 0; i < lessons.length; i++) {
        cl2.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: LessonDisplay(
              lessons[i], (i > 0) ? lessons[i - 1].schoolHour : null),
        ));
        if (i != lessons.length - 1) {
          cl2.add(const Divider());
        } else {
          cl2.add(const Padding(
            padding: EdgeInsets.all(2),
          ));
        }
      }
      // children.add(ExpansionTile(
      //   title: Text(
      //     clName,
      //     style: const TextStyle(
      //       fontSize: 20,
      //       height: 0,
      //     ),
      //   ),
      //   initiallyExpanded: clName == currentClass,
      //   tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      //   childrenPadding: const EdgeInsets.all(8),
      //   children: cl2,
      // ));
      children.addAll(cl2);
    });
    return children;
  }

  IconData roomTypeIcon(RoomType? type) => switch (type) {
        RoomType.art => MdiIcons.palette,
        RoomType.compSci => MdiIcons.desktopClassic,
        RoomType.music => MdiIcons.music,
        RoomType.specialist => Icons.science,
        RoomType.sports => MdiIcons.handball,
        RoomType.technic => MdiIcons.hammerScrewdriver,
        null => MdiIcons.school,
      };

  List<Widget> _buildFreeRoomList() {
    final occupiedRooms = <int, List<String>>{
      1: [],
      2: [],
      3: [],
      4: [],
      5: [],
      6: [],
      7: [],
      8: [],
      9: []
    };
    if (lessons == null) return [];
    for (final lesson in lessons!) {
      occupiedRooms[lesson.schoolHour]!.add(lesson.roomNr);
    }
    final freeRoomsPerHour = occupiedRooms.map((hour, occupied) => MapEntry(
        hour,
        allKeplerRooms.where((room) => !occupied.contains(room)).toList()));
    final freeRoomsWithTypePerHour = () {
      final map = <int, Map<RoomType?, List<String>>>{};
      freeRoomsPerHour.forEach((hour, rooms) {
        if (!map.containsKey(hour)) map[hour] = {};
        for (final room in rooms) {
          final type = specialRoomMap[room];
          if (!map[hour]!.containsKey(type)) map[hour]![type] = [];
          map[hour]![type]!.add(room);
        }
      });
      return map;
    }();
    final children = <Widget>[];
    freeRoomsWithTypePerHour.forEach((hour, freeRooms) {
      final freeRoomsList = freeRooms.entries.toList();
      freeRoomsList.sort((e1, e2) =>
          (e1.key?.name ?? "zzzzzzz").compareTo(e2.key?.name ?? "zzzzzzz"));
      children.add(TextButton(
        style: TextButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.only(left: 8),
          foregroundColor: Colors.grey.shade700,
        ),
        onPressed: () => showDialog(
            context: context,
            builder: (ctx) =>
                generateFreeRoomsClickDialog(ctx, freeRoomsList, hour)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(0),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 25,
                child: Text(
                  "$hour.",
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: freeRoomsList
                      .map((e) => Flexible(
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  child: Icon(
                                    roomTypeIcon(e.key),
                                    color: Colors.grey,
                                  ),
                                ),
                                Flexible(child: Text(e.value.join(", "))),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ));
    });
    return children;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: keplerColorBlue,
              ),
            ),
            Text(
                "Lädt Stundenplan für ${DateFormat("dd.MM.").format(widget.date)} (${widget.selected.contains("-") ? "Klasse" : "Jahrgang"} ${widget.selected})..."),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (lastUpdated != null) Text("zuletzt geändert am $lastUpdated"),
        if (showSTDebugStuff)
          Text(
              "fetched ${fromCache.val == null ? "from somewhere?" : fromCache.val == true ? "from cache" : "from the internet"}"),
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: (widget.mode == SPDisplayMode.allReplaces)
                  ? SPListContainer(
                    child: ListView(
                      shrinkWrap: true,
                      children: _buildAllReplacesLessonList(),
                    ),
                  )
                : (widget.mode == SPDisplayMode.freeRooms)
                  ? SPListContainer(
                      child: () {
                        final list = _buildFreeRoomList();
                        return ListView.separated(
                          itemCount: list.length,
                          shrinkWrap: true,
                          itemBuilder: (ctx, i) => list[i],
                          separatorBuilder: (ctx, i) => const Divider(),
                        );
                      }(),
                    )
                  : LessonListContainer(lessons, widget.selected),
          ),
        ),
        if (supervisions != null && (supervisions?.isEmpty == false) && widget.showSupervisions)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  // border: Border.all(
                  //   color: Colors.grey.shade800
                  // ),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.background,
                  boxShadow: [
                    BoxShadow(
                      color: hasDarkTheme(context)
                          ? Colors.black26
                          : Colors.grey.withOpacity(0.24),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ListView.builder(
                    itemCount: supervisions!.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return const Text("Aufsichten", style: TextStyle(decoration: TextDecoration.underline));
                      final superv = supervisions![i - 1];
                      return Row(
                        children: [
                          if (superv.cancelled) const Text("Abgesagt!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text("${superv.beforeSchoolHour}."),
                          ),
                          Text(superv.location),
                          Text(" um ${superv.time} (${superv.timeDesc})"),
                          if (superv.infoText != null) Text(" - ${superv.infoText}"),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        if (additionalInfo != null &&
            (additionalInfo?.isEmpty == false) &&
            widget.showInfo)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .2),
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
                      color: hasDarkTheme(context)
                          ? Colors.black26
                          : Colors.grey.withOpacity(0.24),
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
                    itemBuilder: (context, index) =>
                        Text(additionalInfo![index]),
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
    _loadData(forceRefresh: false);
    widget.controller?.addRefreshListener(() {
      _loadData(forceRefresh: true);
    });
    super.initState();
  }

  Future<void> _loadData({required bool forceRefresh}) async {
    if (!mounted) return;
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
    getKlData() => IndiwareDataManager.getKlDataForDate(
        widget.date,
        creds.vpUser!,
        creds.vpPassword!,
        fromCache: fromCache,
        forceRefresh: forceRefresh,
      );
    getLeData() => IndiwareDataManager.getLeDataForDate(
        widget.date,
        creds.vpUser!,
        creds.vpPassword!,
        fromCache: fromCache,
        forceRefresh: forceRefresh,
      );
    switch (widget.mode) {
      case SPDisplayMode.yourPlan:
        if (user == UserType.pupil || user == UserType.parent) {
          final data = await getKlData();
          if (!mounted) return;
          lastUpdated = data?.header.lastUpdated;
          lessons = data?.classes
              .cast<VPClass?>()
              .firstWhere((cl) => cl?.className == widget.selected,
                  orElse: () => null)
              ?.lessons
              .where((element) => stdata.selectedCourseIDs.contains(element.subjectID))
              .toList();
        } else if (user == UserType.teacher) {
          final data = await getLeData();
          if (!mounted) return;
          lastUpdated = data?.header.lastUpdated;
          final teacher = data?.teachers.cast<VPTeacher?>().firstWhere(
              (cl) => cl?.teacherCode == stdata.selectedTeacherName!,
              orElse: () => null);
          lessons = teacher?.lessons;
          supervisions = teacher?.supervisions;
        }
        break;
      case SPDisplayMode.allReplaces:
        if (user == UserType.pupil || user == UserType.parent) {
          final klData = await getKlData();
          if (!mounted) return;
          lastUpdated = klData?.header.lastUpdated;
          changedClassLessons = klData?.classes.asMap().map((_, cl) => MapEntry(
              cl.className,
              cl.lessons
                  .where((le) =>
                      le.subjectChanged ||
                      le.teacherChanged ||
                      le.roomChanged ||
                      le.infoText != "")
                  .toList()));
          additionalInfo = klData?.additionalInfo;
        } else if (user == UserType.teacher) {
          final leData = await getLeData();
          if (!mounted) return;
          lastUpdated = leData?.header.lastUpdated;
          changedClassLessons = leData?.teachers.asMap().map((_, cl) => MapEntry(
              cl.teacherCode,
              cl.lessons
                  .where((le) =>
                      le.subjectChanged ||
                      le.teacherChanged ||
                      le.roomChanged ||
                      le.infoText != "")
                  .toList()));
          additionalInfo = leData?.additionalInfo;
        }
        break;
      case SPDisplayMode.classPlan:
        final klData = await getKlData();
        if (!mounted) return;
        lastUpdated = klData?.header.lastUpdated;
        lessons = klData?.classes
            .cast<VPClass?>()
            .firstWhere((cl) => cl?.className == widget.selected,
                orElse: () => null)
            ?.lessons;
        additionalInfo = klData?.additionalInfo;
        break;
      case SPDisplayMode.freeRooms:
        // free rooms ignores teacher mode
        // yes, the teacher stuplan access allows accessing room plans
        // but idc lol - also teachers don't deserve better free room
        final klData = await getKlData();
        if (!mounted) return;
        lastUpdated = klData?.header.lastUpdated;
        lessons = klData?.classes
            .map((e) => e.lessons)
            .fold([], (prev, ls) => prev!..addAll(ls));
        break;
      case SPDisplayMode.roomPlan:
        final klData = await getKlData();
        if (!mounted) return;
        lastUpdated = klData?.header.lastUpdated;
        lessons = klData?.classes
            .map((e) => e.lessons)
            .fold<List<VPLesson>>([], (prev, ls) => prev..addAll(ls))
            .where((l) => l.roomNr == widget.selected).toList();
        break;
      case SPDisplayMode.teacherPlan:
        final leData = await getLeData();
        if (!mounted) return;
        lastUpdated = leData?.header.lastUpdated;
        lessons = leData?.teachers.cast<VPTeacher?>()
          .firstWhere((le) => le?.teacherCode == widget.selected, orElse: () => null)
          ?.lessons;
        additionalInfo = leData?.additionalInfo;
        break;
      default:
    }
    lessons?.sort((l1, l2) {
      final t1 = l1.schoolHour.compareTo(l2.schoolHour);
      if (t1 != 0) return t1;
      return l1.subjectCode.compareTo(l2.subjectCode);
    });
    setState(() => _loading = false);
  }
}

class SPListContainer extends StatelessWidget {
  final bool blueBorder;
  final Widget? child;
  final EdgeInsets? padding;
  final bool shadow;
  final Color? color;
  const SPListContainer({super.key, this.blueBorder = false, this.padding, this.shadow = true, this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: (blueBorder)
            ? Border.all(
                color: hasDarkTheme(context)
                    ? keplerColorBlue
                    : colorWithLightness(keplerColorBlue, .4),
                width: 3)
            : null,
        color: color ?? Theme.of(context).colorScheme.background,
        boxShadow: (shadow) ? [
          BoxShadow(
            color: hasDarkTheme(context)
                ? Colors.black45
                : Colors.grey.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 3),
          )
        ] : null,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        child: child,
      ),
    );
  }
}

class LessonListContainer extends StatelessWidget {
  final List<VPLesson>? lessons;
  final String className;
  const LessonListContainer(this.lessons, this.className, {super.key});

  @override
  Widget build(BuildContext context) {
    return SPListContainer(
        blueBorder: lessons != null,
        child: () {
          if (lessons == null) {
            return const Center(
              child: Text(
                "Keine Daten verfügbar.",
                style: TextStyle(fontSize: 18),
              ),
            );
          }
          if (lessons!.isEmpty) {
            return const Center(
              child: Text(
                "Heute kein Unterricht.",
                style: TextStyle(fontSize: 18),
              ),
            );
          }
          final stdata = Provider.of<StuPlanData>(context);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              itemCount: lessons!.length,
              itemBuilder: (context, index) => LessonDisplay(
                lessons![index],
                index > 0
                    ? lessons!.elementAtOrNull(index - 1)?.schoolHour
                    : null,
                subject: stdata.availableSubjects[className]
                    ?.cast<VPCSubjectS?>()
                    .firstWhere(
                      (s) => s!.subjectID == lessons![index].subjectID,
                      orElse: () => null,
                    ),
              ),
              separatorBuilder: (context, index) => const Divider(height: 24),
            ),
          );
        }());
  }
}

class LessonDisplay extends StatelessWidget {
  final VPLesson lesson;
  final int? previousLessonHour;
  final bool showInfoDialog;
  final VPCSubjectS? subject;
  const LessonDisplay(this.lesson, this.previousLessonHour,
      {super.key, this.showInfoDialog = true, this.subject});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontSize: 18,
        height: 0,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (showInfoDialog)
            ? () => showDialog(
                context: context,
                builder: (dialogCtx) =>
                    generateLessonInfoDialog(dialogCtx, lesson, subject))
            : null,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 25,
                  child: (previousLessonHour != lesson.schoolHour)
                      ? Text("${lesson.schoolHour}. ")
                      : const SizedBox.shrink(),
                ),
                Text(
                  lesson.subjectCode,
                  style: TextStyle(
                    color: (lesson.subjectChanged) ? Colors.red : null,
                    fontWeight: (lesson.subjectChanged)
                        ? FontWeight.bold
                        : FontWeight.w500,
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
                        fontWeight:
                            (lesson.teacherChanged) ? FontWeight.bold : null,
                        color: (lesson.teacherChanged) ? Colors.red : null,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  lesson.roomNr,
                  style: TextStyle(
                    color: (lesson.roomChanged) ? Colors.red : null,
                    fontWeight: (lesson.roomChanged) ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (lesson.infoText != "")
              Row(
                children: [
                  const SizedBox(width: 25),
                  Flexible(
                    child: Text(
                      lesson.infoText,
                      style: const TextStyle(fontSize: 15),
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