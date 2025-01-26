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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/checks.dart';
import 'package:kepler_app/libs/custom_events.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/rainbow.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/pages/free_rooms.dart';
import 'package:kepler_app/tabs/hourtable/pages/your_plan.dart'
    show generateExamInfoDialog, generateLessonInfoDialog;
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

/// wie viel soll die Stundenplan-Liste weiter scrollbar sein, als echt nötig wäre - für "Ereignis hinzufügen"-Knopf
const kSPListExtraScrollSpace = 32.0;

enum SPDisplayMode {
  /// "Dein/Ihr Stundenplan": Stundenplan für einzelne, ausgewählte Klasse, Fächer können ausgeblendet werden.
  yourPlan,
  /// "Klassenplan": Stundenplan für direkt auf Seite auswählbare Klasse, alle Fächer werden angezeigt.
  classPlan,
  /// "Alle Vertretungen": alle geänderten Stunden für Tag, kategorisiert nach Klasse
  allReplaces,
  /// "Freie Räume": freie Räume für Stunde, kategorisiert nach Raumtyp
  freeRooms,
  /// "Lehrerplan": wie Klassenplan, aber für Lehrer
  teacherPlan,
  /// "Raumplan": Stundenplan für auswählbaren Raum, zeigt Stunden, die in Raum stattfinden sollen
  /// (wie Klassenplan, aber für Raum)
  roomPlan,
}

/// einfach die Masterclass des Projektes, mit etwa 1500 Zeilen Code für alles
/// (hätte man vielleicht aufteilen können, aber die Logik zum Laden der Stunden ist halt für alles
/// ähnlich, und die Anzeige meist auch)
class StuPlanDisplay extends StatefulWidget {
  /// was grad ausgewählt ist, etwa Klasse oder Lehrer
  final String selected;
  /// Stundenplan-ID für alternativen Stundenplan
  final int? selectedId;
  /// Anzeigemodus des Widgets - welcher Plan angezeigt werden soll
  final SPDisplayMode mode;
  /// sollen die Infos vom Sekretariat unten mit angezeigt werden?
  final bool showInfo;
  const StuPlanDisplay(
      {super.key,
      required this.selected,
      required this.mode,
      this.showInfo = true,
      this.selectedId});

  @override
  State<StuPlanDisplay> createState() => StuPlanDisplayState();
}

/// Hilfsfunktionen für Datumszeug

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

/// ist die vom Benutzer gewählte Zeit für den nächsten Plan vergangen?
bool shouldGoToNextPlanDay(BuildContext context) {
  final today = DateTime.now();
  final prefs = Provider.of<Preferences>(context, listen: false);
  final todayNextPlanDay = prefs.timeToDefaultToNextPlanDay.toDateTime(today);
  return today.millisecondsSinceEpoch > todayNextPlanDay.millisecondsSinceEpoch
    && !isWeekend(today.add(const Duration(days: 1)));
}

bool isSameDate(DateTime dateTime1, DateTime dateTime2)
  => dateTime1.year == dateTime2.year && dateTime1.month == dateTime2.month && dateTime1.day == dateTime2.day;

/// wurde der Stundenplan heute schonmal aktualisiert?
bool shouldStuPlanAutoReload(BuildContext context)
  => Provider.of<Preferences>(context, listen: false).reloadStuPlanAutoOnceDaily &&
    !isSameDate((Provider.of<InternalState>(context, listen: false).lastStuPlanAutoReload ?? DateTime(1900)), DateTime.now());

/// schönere Beschreibung des Datums relativ zu heutigem Tag wenn möglich, sonst nur Formatierung
String getDayDescription(DateTime date) {
  final today = DateTime.now();
  final diffToToday = date.difference(today);
  if (today.day == date.day && today.month == date.month && today.year == date.year) {
    return "Heute";
  } else if (diffToToday.inDays == 0) {
    return "Morgen";
  } else if (diffToToday.inDays == 1) {
    return "Übermorgen";
  } else {
    return "Am ${DateFormat("dd.MM.").format(date)}";
  }
}

class StuPlanDisplayState extends State<StuPlanDisplay> {
  final format = DateFormat("EEEE, dd.MM.", "de-DE");
  late DateTime currentDate;
  late DateTime startDate;
  final _ctr = StuPlanDayDisplayController();

  /// versucht erstmal nur, Daten für heute neu zu laden - wenn erfolgreich, löscht auch andere Daten im Cache
  void forceRefreshData() {
    // only clear the cache if loading the new data succeeded (if connected to indiware)
    _ctr.triggerRefresh(forceOnline: true)?.then((val) {
      if (val) {
        /// Cache nur für alles in der Zukunft löschen (Stundenplan in Vergangenheit wird sich ja wohl nicht ändern)
        IndiwareDataManager.clearCachedData(excludeDate: DateTime.now());
        showSnackBar(text: "Stundenplan erfolgreich aktualisiert.", duration: const Duration(seconds: 1));
      } else {
        showSnackBar(textGen: (sie) => "Fehler beim Aktualisieren der Stundenplan-Daten. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
        /// nochmal neu laden, damit wieder gecachete Daten angezeigt werden
        _ctr.triggerRefresh(forceOnline: false);
      }
    });
  }

  void jumpToStartDate() {
    setState(() {
      currentDate = _getStartDate();
    });
  }

  /// heute falls Wochentag, sonst nächster Montag
  DateTime _getStartDate() {
    final today = DateTime.now();
    if (isWeekend(today)) return findNextMonday(today);
    return today;
  }

  @override
  void initState() {
    super.initState();
    currentDate = _getStartDate();
    
    // currentDate on sundays is already the monday because shouldGoToNextPlanDay also works on sundays
    if (shouldGoToNextPlanDay(context) && DateTime.now().weekday != DateTime.sunday) {
      currentDate = currentDate.add(const Duration(days: 1));
    }

    startDate = _getStartDate();

    // has to be run in a post frame callback because Flutter otherwise tries to trigger a rebuild (but initState happens while building -> "already building" error) somewhere (in a child widget?)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldStuPlanAutoReload(context)) {
        forceRefreshData();
        Provider.of<InternalState>(context, listen: false).lastStuPlanAutoReload = DateTime.now();
      }
      final creds = Provider.of<CredentialStore>(context, listen: false);
      if (creds.lernSaxLogin == lernSaxDemoModeMail) return;
      checkAndUpdateSPMetaData(
        creds.vpHost ?? baseUrl,
        creds.vpUser!,
        creds.vpPassword!,
        Provider.of<AppState>(context, listen: false).userType,
        Provider.of<StuPlanData>(context, listen: false),
      ).then((info) {
        if (info != null) showSnackBar(text: info);
      });
    });
  }

  bool canGoBack() => currentDate.isAfter(startDate);

  void makeCurrentDateGoBack() {
    if (isOrPrevWeekend(currentDate)) {
      setState(() => currentDate = findPrevFriday(currentDate));
    } else {
      setState(() => currentDate = currentDate.subtract(const Duration(days: 1)));
    }
  }

  bool canGoForward() => currentDate.isBefore(startDate.add(const Duration(days: 3)));

  void makeCurrentDateGoForward() {
    if (isOrSoonWeekend(currentDate)) {
      setState(() => currentDate = findNextMonday(currentDate));
    } else {
      setState(() => currentDate = currentDate.add(const Duration(days: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = Provider.of<Preferences>(context, listen: false);
    return Center(
      child: ConstrainedBox(
        /// für angenehmeres Layout auf Tablets wird die Breite beschränkt
        constraints: const BoxConstraints(
          maxWidth: 600,
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: (canGoBack() || prefs.enableInfiniteStuPlanScrolling)
                      ? () => makeCurrentDateGoBack()
                      : null,
                ),
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
                      /// farbige Chips für "heute" und "morgen" anzeigen
                      if (isSameDate(currentDate, DateTime.now()))
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
                      if (isSameDate(currentDate, DateTime.now().add(const Duration(days: 1))))
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: hasDarkTheme(context)
                                  ? colorWithLightness(Colors.green, .15)
                                  : colorWithLightness(Colors.green, .8),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                "morgen",
                                style: TextStyle(height: 0),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed:
                      (canGoForward() || prefs.enableInfiniteStuPlanScrolling)
                          ? () => makeCurrentDateGoForward()
                          : null,
                ),
              ],
            ),
            Flexible(
              /// echte Anzeige vom Stundenplan für den ausgewählten Tag
              child: Selector<StuPlanData, List<DateTime>>(
                selector: (_, stdata) => stdata.holidayDates,
                builder: (_, holidayDates, __) => StuPlanDayDisplay(
                  controller: _ctr,
                  date: currentDate,
                  key: ValueKey(currentDate.hashCode +
                      widget.selected.hashCode +
                      widget.selectedId.hashCode +
                      widget.mode.hashCode +
                      holidayDates.hashCode),
                  selected: widget.selected,
                  selectedId: widget.selectedId,
                  mode: widget.mode,
                  showInfo: widget.showInfo,
                  onSwipeRight: () => (canGoBack() || prefs.enableInfiniteStuPlanScrolling) ? makeCurrentDateGoBack() : null,
                  onSwipeLeft: () => (canGoForward() || prefs.enableInfiniteStuPlanScrolling) ? makeCurrentDateGoForward() : null,
                  schoolHolidayList: holidayDates,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// damit das übergeordnete Widget das StuPlanDayDisplay kontrollieren kann, wird dieser Controller als Vermittler
/// zwischen den beiden übergeben:
/// - das Elternwidget erstellt den Controller und übergibt eine Referenz
/// - das Kindwidget verwendet setRefreshListener um eine eigene Funktion an den Controller zu übergeben
/// - dann kann triggerRefresh vom Elternwidget aufgerufen werden, und es wird eine Funktion im Kindwidget
///   aufgerufen
class StuPlanDayDisplayController {
  Future<bool> Function(bool forceOnline)? onRefreshListener;

  void setRefreshListener(Future<bool> Function(bool forceOnline) func) => onRefreshListener = func;
  void clearRefreshListener() => onRefreshListener = null;
  Future<bool>? triggerRefresh({ required bool forceOnline }) => onRefreshListener?.call(forceOnline);

  StuPlanDayDisplayController();
}

/// das hier ist die tatsächlich wichtigste Klasse im Bezug auf den Stundenplan
/// -> zeigt den Stundenplan für einen Tag an und lädt die dafür nötigen Daten vom Cache/Indiware-Server
class StuPlanDayDisplay extends StatefulWidget {
  /// Parameter wie bei StuPlanDisplay
  final DateTime date;
  final String selected;
  final SPDisplayMode mode;
  final int? selectedId;
  /// Controller, optional (wow)
  final StuPlanDayDisplayController? controller;
  final bool showInfo;
  /// sollen die Aufsichten für den ausgewählten Lehrer angezeigt werden? (nur für Lehrer)
  final bool showSupervisions;
  /// wird aufgerufen, wenn der Benutzer nach links wischt
  final void Function()? onSwipeLeft;
  /// wird aufgerufen, wenn der Benutzer nach rechts wischt
  final void Function()? onSwipeRight;
  /// Liste der freien Tage
  final List<DateTime>? schoolHolidayList;
  const StuPlanDayDisplay(
      {super.key,
      required this.date,
      required this.selected,
      required this.mode,
      this.controller,
      this.showInfo = true,
      this.showSupervisions = true,
      this.onSwipeLeft,
      this.onSwipeRight,
      this.schoolHolidayList,
      this.selectedId});

  @override
  State<StuPlanDayDisplay> createState() => _StuPlanDayDisplayState();
}

class _StuPlanDayDisplayState extends State<StuPlanDayDisplay> {
  // das ist schon kommentiert, weil es selbst direkt nach schreiben schon zu unübersichtlich war
  // wahrscheinlich sollte man dafür jeden Modus in ein eigenes Widget extrahieren?
  // und dann in StuPlanDisplay anzeigen? aber naja, so ist es schön kompakt (nicht auf die Linienanzahl dieser Datei schauen)

  bool _loading = true;
  /// gets selected lessons loaded when no special mode selected, if `freeRoomsMode` gets loaded all lessons for all classes, otherwise is null
  List<VPLesson>? lessons;
  /// gets loaded with all lessons for determining last room usage
  List<VPLesson>? allLessonsForDate;
  /// only gets loaded with changed class lessons if `allReplacesMode`
  Map<String, List<VPLesson>>? changedClassLessons;
  /// only gets loaded with exam data if user enables showing exam
  List<VPExam>? exams;
  /// gets loaded whatever mode is active
  String? lastUpdated;
  /// gets loaded when no special mode is selected
  List<String>? additionalInfo;
  /// gets loaded if the user is a teacher and no special mode is selected
  List<VPTeacherSupervision>? supervisions;
  /// is always updated when something is loaded
  bool? isOnline;
  /// is always updated when something is loaded
  bool? isSchoolHoliday;

  /// generiert Widgets für anzuzeigende Liste für Modus Alle Vertretungen
  List<Widget> _buildAllReplacesLessonList() {
    // final currentClass = Provider.of<StuPlanData>(context, listen: false).selectedClassName;
    final children = <Widget>[];
    if (changedClassLessons == null) return [];
    final stdata = Provider.of<StuPlanData>(context, listen: false);
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
              lessons[i],
              (i > 0) ? lessons[i - 1].schoolHour : null,
              lessons[i].hasLastRoomUsageFromList(lessons),
              classNameToStrip: clName,
              subject: stdata.availableSubjects[clName]
                ?.cast<VPCSubjectS?>()
                .firstWhere(
                  (s) => s!.subjectID == lessons[i].subjectID,
                  orElse: () => null,
                ),
            ),
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

  /// für Mapping RoomType -> IconData
  IconData roomTypeIcon(RoomType? type) => switch (type) {
        RoomType.art => MdiIcons.palette,
        RoomType.compSci => MdiIcons.desktopClassic,
        RoomType.music => MdiIcons.music,
        RoomType.specialist => Icons.science,
        RoomType.sports => MdiIcons.handball,
        RoomType.technic => MdiIcons.hammerScrewdriver,
        null => MdiIcons.school,
      };

  /// generiert anzuzeigende Widgets in Liste für Modus Freie Räume
  List<Widget> _buildFreeRoomList() {
    /// nur für 1. bis 9. Stunde, alles andere gibt es nur extrem selten -> eh alle Räume frei, oder Schule geschlossen
    final occupiedRooms = <int, List<String>>{
      1: [],
      2: [],
      3: [],
      4: [],
      5: [],
      6: [],
      7: [],
      8: [],
      9: [],
    };
    if (lessons == null) return [];
    for (final lesson in lessons!) {
      // somehow, some people had a 10th and 11th lesson - what the fuck!?
      /// und obwohl da "nur 1. bis 9. Stunde" stand, wird hier einfach für die Stunde eine Liste hinzugefügt,
      /// damit nur an Tagen, wo es nötig ist, alle möglichen Stunden angezeigt werden
      if (!occupiedRooms.containsKey(lesson.schoolHour)) occupiedRooms[lesson.schoolHour] = [];
      occupiedRooms[lesson.schoolHour]!.addAll(lesson.roomCodes);
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
                width: 26,
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

  /// Bestimmung von Info-Text der beim Laden des Planes unter Ladebalken angezeigt werden soll
  String? _getLoadingDescription() {
    switch (widget.mode) {
      case SPDisplayMode.classPlan:
        return "${widget.selected.contains("-") ? "Klasse" : "Jahrgang"} ${widget.selected}";
      case SPDisplayMode.teacherPlan:
        return "Lehrer ${widget.selected}";
      case SPDisplayMode.yourPlan:
        if (Provider.of<AppState>(context, listen: false).userType == UserType.teacher) {
          return "Lehrer ${widget.selected}";
        } else {
          return "${widget.selected.contains("-") ? "Klasse" : "Jahrgang"} ${widget.selected}";
        }
      case SPDisplayMode.allReplaces:
      case SPDisplayMode.freeRooms:
        return null;
      case SPDisplayMode.roomPlan:
        return "Raum ${widget.selected}";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final info = _getLoadingDescription();
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
            Text("Lädt Stundenplan für ${DateFormat("dd.MM.").format(widget.date)}${info != null ? " ($info)" : ""}..."),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (lastUpdated != null) Text("zuletzt geändert am $lastUpdated"),
        if (kDebugFeatures) Text("fetched ${isOnline == null ? "from somewhere?" : isOnline == false ? "from cache" : "from the internet"}"),
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: (widget.schoolHolidayList != null && isSchoolHoliday == true) ?
                  SPListContainer(
                    showBorder: true,
                    onSwipeLeft: widget.onSwipeLeft,
                    onSwipeRight: widget.onSwipeRight,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${getDayDescription(widget.date)} ist keine Schule.",
                            style: const TextStyle(fontSize: 18),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text("Das stimmt nicht?"),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(visualDensity: const VisualDensity(vertical: -2)),
                            onPressed: () {
                              // warning -> this in combination with the refresh every 14 days may cause holiday dates reappearing as holidays
                              // but it doesn't seem like a major enough issue to warrant fixing to me
                              Provider.of<StuPlanData>(context, listen: false).removeHolidayDate(widget.date);
                            },
                            child: const Text("Schulfreien Tag entfernen"),
                          ),
                        ],
                      ),
                    ),
                  )
                : (widget.mode == SPDisplayMode.allReplaces)
                  ? SPListContainer(
                    onSwipeLeft: widget.onSwipeLeft,
                    onSwipeRight: widget.onSwipeRight,
                    child: () {
                      final list = _buildAllReplacesLessonList();
                      if (list.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isOnline != false ? "Keine Daten verfügbar" : "Keine Verbindung zum Server",
                                style: const TextStyle(fontSize: 18),
                              ),
                              const Text("oder keine Änderungen."),
                            ],
                          ),
                        );
                      }
                      return ListView(
                        shrinkWrap: true,
                        children: list,
                      );
                    }(),
                  )
                : (widget.mode == SPDisplayMode.freeRooms)
                  ? SPListContainer(
                      onSwipeLeft: widget.onSwipeLeft,
                      onSwipeRight: widget.onSwipeRight,
                      child: () {
                        final list = _buildFreeRoomList();
                        if (list.isEmpty) {
                          return Center(
                            child: Text(
                              isOnline != false ? "Keine Daten verfügbar." : "Keine Verbindung zum Server.",
                              style: const TextStyle(fontSize: 18),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: list.length,
                          shrinkWrap: true,
                          itemBuilder: (ctx, i) => list[i],
                          separatorBuilder: (ctx, i) => const Divider(),
                        );
                      }(),
                    )
                  : Consumer<CustomEventManager>(
                    builder: (context, evtmgr, _) {
                      return LessonListContainer(
                        lessons,
                        widget.selected,
                        widget.date,
                        onSwipeLeft: widget.onSwipeLeft,
                        onSwipeRight: widget.onSwipeRight,
                        isOnline: isOnline,
                        mode: widget.mode,
                        fullLessonListForDate: allLessonsForDate,
                        onRefresh: () async {
                          showSnackBar(text: await loadData(forceRefresh: true) ? "Stundenplan für den aktuellen Tag erfolgreich aktualisiert." : "Aktualisieren gescheitert.", duration: const Duration(seconds: 2));
                        },
                        events: widget.mode == SPDisplayMode.yourPlan ? evtmgr.events.where((evt) => isSameDate(evt.date ?? DateTime(1900), widget.date)).toList() : null,
                        // events: evtmgr.events,
                        extraScrollSpace: widget.mode == SPDisplayMode.yourPlan ? kSPListExtraScrollSpace : null,
                      );
                    }
                  ),
          ),
        ),
        /// Aufsichten anzeigen
        if (supervisions != null && (supervisions?.isEmpty == false) && widget.showSupervisions)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                decoration: BoxDecoration(
                  // border: Border.all(
                  //   color: Colors.grey.shade800
                  // ),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: hasDarkTheme(context)
                          ? Colors.black26
                          : Colors.grey.withValues(alpha: 0.24),
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
        /// Klausuren anzeigen
        if (exams != null &&
            (exams?.isEmpty == false) &&
            Provider.of<Preferences>(context, listen: false).stuPlanShowExams &&
            widget.showInfo)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              decoration: BoxDecoration(
                // border: Border.all(
                //   color: Colors.grey.shade800
                // ),
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: hasDarkTheme(context) ? Colors.black26 : Colors.grey.withValues(alpha: 0.24),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        "Klausuren ${getDayDescription(widget.date).toLowerCase()}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .1),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: exams!.length,
                        itemBuilder: (context, index) {
                          if (exams!.length - 1 < index) return null;
                          final exam = exams![index];
                          return ExamDisplay(exam: exam, previousYear: (index > 0) ? exams![index - 1].year : null);
                        },
                        separatorBuilder: (context, i) => Divider(indent: (exams!.length > 1 && exams![i].year == exams![i + 1].year) ? 70 : 0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        /// Infos vom Sekretariat anzeigen
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
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: hasDarkTheme(context)
                          ? Colors.black26
                          : Colors.grey.withValues(alpha: 0.24),
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

  void onEventUpdate() { loadData(forceRefresh: false); }
  @override
  void initState() {
    loadData(forceRefresh: false);
    widget.controller?.setRefreshListener((force) => loadData(forceRefresh: force));
    Provider.of<CustomEventManager>(context, listen: false).addListener(onEventUpdate);
    super.initState();
  }

  /// falls `forceRefresh == true` wird zwingend versucht, die Daten von Indiware statt aus dem Cache zu laden
  Future<bool> loadData({required bool forceRefresh}) async {
    if (!mounted) return false;
    setState(() => _loading = true);
    final state = Provider.of<AppState>(context, listen: false);
    final user = state.userType;
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final stdata = Provider.of<StuPlanData>(context, listen: false);
    final prefs = Provider.of<Preferences>(context, listen: false);
    if ((creds.vpUser == null || creds.vpPassword == null) && creds.lernSaxLogin != lernSaxDemoModeMail) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        state.selectedNavPageIDs = [PageIDs.home];
      });
      showSnackBar(text: "Fehler bei der Datenabfrage. Bitte erneut anmelden.", error: true);
      return false;
    }
    /// Schüler-Stundenplan für widget.date laden
    getKlData() {
      if (creds.lernSaxLogin == lernSaxDemoModeMail) {
        return Future.value((VPKlData(
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
        ), true));
      }
      return IndiwareDataManager.getKlDataForDate(
        widget.date,
        creds.vpHost!,
        creds.vpUser!,
        creds.vpPassword!,
        forceRefresh: forceRefresh,
      );
    }
    /// Lehrer-Stundenplan für widget.date laden
    getLeData() => IndiwareDataManager.getLeDataForDate(
        widget.date,
        creds.vpHost!,
        creds.vpUser!,
        creds.vpPassword!,
        forceRefresh: forceRefresh,
      );
    
    isSchoolHoliday = (widget.schoolHolidayList ?? []).any((date) => date.day == widget.date.day && date.month == widget.date.month && date.year == widget.date.year);
    if (isSchoolHoliday == true) {
      if (prefs.confettiEnabled) Future.delayed(const Duration(milliseconds: 100)).then((_) => globalConfettiController.play());
      setState(() => _loading = false);
      return true;
    }
    /// Klausuren laden
    Future<(List<VPExam>?, bool)> getExamData() {
      if (creds.lernSaxLogin == lernSaxDemoModeMail) return Future.value((<VPExam>[], true));
      return IndiwareDataManager.getExamDataForDate(widget.date, creds.vpHost!, creds.vpUser!, creds.vpPassword!, forceRefresh: forceRefresh);
    }

    /// Hier werden die Daten entsprechend des Modus' (und Benutzertyps) geladen und verarbeitet.
    /// was welche Felder enthalten und wann sie gesetzt werden müssen -> siehe Kommentare bei Feldern selbst
    switch (widget.mode) {
      case SPDisplayMode.yourPlan:
        if (user == UserType.pupil || user == UserType.parent) {
          final (data, online) = await getKlData();
          if (!mounted) return false;
          isOnline = online;
          lastUpdated = data?.header.lastUpdated;
          lessons = data?.classes
              .cast<VPClass?>()
              .firstWhere((cl) => cl?.className == widget.selected,
                  orElse: () => null)
              ?.lessons
              // include lessons with subjectID == null, because they are usually important changed lessons for every pupil
              .where((element) => ((widget.selectedId ?? 0) < 1 ? stdata.selectedCourseIDs : stdata.altSelectedCourseIDs[(widget.selectedId ?? 1) - 1].split("|").map((m) => int.parse(m))).contains(element.subjectID) || element.subjectID == null)
              .toList();
          allLessonsForDate = data?.classes?.expand((cl) => cl.lessons)?.toList();
          additionalInfo = data?.additionalInfo;
          if (prefs.stuPlanShowExams) {
            final (edata, _) = await getExamData();
            if (!mounted) return false;
            exams = edata;
          }
        } else if (user == UserType.teacher) {
          final (data, online) = await getLeData();
          if (!mounted) return false;
          isOnline = online;
          lastUpdated = data?.header.lastUpdated;
          final teacher = data?.teachers.cast<VPTeacher?>().firstWhere(
              (cl) => cl?.teacherCode == stdata.selectedTeacherName!,
              orElse: () => null);
          lessons = teacher?.lessons;
          allLessonsForDate = data?.teachers?.expand((cl) => cl.lessons)?.toList();
          supervisions = teacher?.supervisions;
          additionalInfo = data?.additionalInfo;
        }
        if (
          prefs.confettiEnabled &&
          lessons?.any((lesson) => lesson.teacherCode == "---") == true
        ) {
          globalConfettiController.play();
        }
        break;
      case SPDisplayMode.allReplaces:
        if (user == UserType.pupil || user == UserType.parent) {
          final (klData, online) = await getKlData();
          if (!mounted) return false;
          isOnline = online;
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
          allLessonsForDate = klData?.classes?.expand((cl) => cl.lessons)?.toList();
          additionalInfo = klData?.additionalInfo;
        } else if (user == UserType.teacher) {
          final (leData, online) = await getLeData();
          if (!mounted) return false;
          isOnline = online;
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
          allLessonsForDate = leData?.teachers?.expand((cl) => cl.lessons)?.toList();
          additionalInfo = leData?.additionalInfo;
        }
        break;
      case SPDisplayMode.classPlan:
        final (klData, online) = await getKlData();
        if (!mounted) return false;
        isOnline = online;
        lastUpdated = klData?.header.lastUpdated;
        lessons = klData?.classes
            .cast<VPClass?>()
            .firstWhere((cl) => cl?.className == widget.selected,
                orElse: () => null)
            ?.lessons;
        allLessonsForDate = klData?.classes?.expand((cl) => cl.lessons)?.toList();
        additionalInfo = klData?.additionalInfo;
        break;
      case SPDisplayMode.freeRooms:
        // free rooms ignores teacher mode
        // yes, the teacher stuplan access allows accessing room plans
        // but idc lol - also teachers don't deserve better free room plans
        final (klData, online) = await getKlData();
        if (!mounted) return false;
        isOnline = online;
        lastUpdated = klData?.header.lastUpdated;
        lessons = klData?.classes
            .map((e) => e.lessons)
            .fold([], (prev, ls) => prev!..addAll(ls));
        // dont load allLessonsForDate because it isn't displayed in this plan
        break;
      case SPDisplayMode.roomPlan:
        final (klData, online) = await getKlData();
        if (!mounted) return false;
        isOnline = online;
        lastUpdated = klData?.header.lastUpdated;
        lessons = klData?.classes
            .fold<List<VPLesson>>([], (prev, ls) => prev..addAll(ls.lessons.map((e) => e.copyWith(infoText: "${ls.className.contains("-") ? "Klasse" : "Jahrgang"} ${ls.className}${e.infoText == "" ? "" : "\n"}${e.infoText}"))))
            .where((l) => l.roomCodes.contains(widget.selected))
            .toList();
        // dont load allLessonsForDate because last room usage doesn't matter anyway (it's kinda obvious)
        break;
      case SPDisplayMode.teacherPlan:
        final (leData, online) = await getLeData();
        if (!mounted) return false;
        isOnline = online;
        lastUpdated = leData?.header.lastUpdated;
        lessons = leData?.teachers.cast<VPTeacher?>()
          .firstWhere((le) => le?.teacherCode == widget.selected, orElse: () => null)
          ?.lessons;
        allLessonsForDate = leData?.teachers?.expand((cl) => cl.lessons)?.toList();
        additionalInfo = leData?.additionalInfo;
        break;
    }
    lessons?.sort((l1, l2) {
      final t1 = l1.schoolHour.compareTo(l2.schoolHour);
      if (t1 != 0) return t1;
      return l1.subjectCode.compareTo(l2.subjectCode);
    });
    setState(() => _loading = false);
    return isOnline ?? false;
  }

  @override
  void dispose() {
    globalConfettiController.stop();
    // can't use context because widget is being disposed
    Provider.of<CustomEventManager>(globalScaffoldContext, listen: false).removeListener(onEventUpdate);
    super.dispose();
  }
}

class SPListContainer extends StatelessWidget {
  final bool showBorder;
  final Widget? child;
  final EdgeInsets? padding;
  final bool shadow;
  final Color? color;
  final void Function()? onSwipeLeft;
  final void Function()? onSwipeRight;
  final bool showAddEventButton;
  final DateTime? addEventSelectedDate;
  const SPListContainer({
    super.key,
    this.showBorder = false,
    this.padding,
    this.shadow = true,
    this.child,
    this.color,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.showAddEventButton = false,
    this.addEventSelectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final d = details.primaryVelocity ?? 0;
        if (d > 500) onSwipeRight?.call();
        if (d < -500) onSwipeLeft?.call();
      },
      child: Consumer<Preferences>(
        builder: (context, prefs, subChild) {
          return RainbowWrapper(
            variant: RainbowVariant.dark,
            builder: (context, rcolor) {
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: (showBorder && (prefs.stuPlanDataAvailableBorderGradientColor != null && rcolor == null) && prefs.stuPlanDataAvailableBorderWidth > 0) ?
                    LinearGradient(
                      colors: [prefs.stuPlanDataAvailableBorderColor, prefs.stuPlanDataAvailableBorderGradientColor!],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null,
                  border: (showBorder && (prefs.stuPlanDataAvailableBorderGradientColor == null || rcolor != null) && prefs.stuPlanDataAvailableBorderWidth > 0)
                    ? Border.all(
                        // color: hasDarkTheme(context)
                        //     ? (prefs.stuPlanDataAvailableBorderColor ?? keplerColorBlue)
                        //     : colorWithLightness((prefs.stuPlanDataAvailableBorderColor ?? keplerColorBlue), .4),
                        color: rcolor ?? prefs.stuPlanDataAvailableBorderColor,
                        width: prefs.stuPlanDataAvailableBorderWidth)
                    : null,
                  boxShadow: (shadow) ? [
                    BoxShadow(
                      color: hasDarkTheme(context)
                          ? Colors.black45
                          : Colors.grey.withValues(alpha: 0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    )
                  ] : null,
                ),
                child: Padding(
                  padding: (showBorder && prefs.stuPlanDataAvailableBorderGradientColor != null) ? EdgeInsets.all(prefs.stuPlanDataAvailableBorderWidth) : EdgeInsets.zero,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(prefs.stuPlanDataAvailableBorderWidth > 5 ? 0 : 8),
                      color: color ?? Theme.of(context).colorScheme.surface,
                    ),
                    child: subChild != null && showAddEventButton && prefs.showYourPlanAddEvents ? Stack(
                      children: [
                        subChild,
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Transform.translate(
                            offset: Offset(0, 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    final event = await showModifyEventDialog(context, addEventSelectedDate ?? DateTime.now());
                                    if (event != null) {
                                      if (!context.mounted) return;
                                      Provider.of<CustomEventManager>(context, listen: false).addEvent(event);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                                    ),
                                    visualDensity: VisualDensity(vertical: -1),
                                    backgroundColor: colorWithLightness(Colors.blue, hasDarkTheme(context) ? .15 : .935),
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 4),
                                          child: const Icon(Icons.event, size: 16),
                                        ),
                                      ),
                                      Flexible(
                                        flex: 0,
                                        child: Text("Ereignis hinzufügen"),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ) : subChild,
                  ),
                ),
              );
            }
          );
        },
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          child: child,
        ),
      ),
    );
  }
}

class LessonListContainer extends StatelessWidget {
  final List<VPLesson>? lessons;
  final List<VPLesson>? fullLessonListForDate;
  final List<CustomEvent>? events;
  final String className;
  final DateTime date;
  final void Function()? onSwipeLeft;
  final void Function()? onSwipeRight;
  final Future<void> Function() onRefresh;
  final bool? isOnline;
  final SPDisplayMode? mode;
  /// wie viel soll die Liste weiter scrollbar sein, als echt nötig wäre - für "Ereignis hinzufügen"-Knopf
  final double? extraScrollSpace;
  LessonListContainer(
    this.lessons,
    this.className,
    this.date, {
    super.key,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.isOnline,
    this.mode,
    required this.fullLessonListForDate,
    required this.onRefresh,
    this.events,
    this.extraScrollSpace,
  }) {
    events!.sort((a, b) {
      if (a.date != null && b.date != null) {
        if (!isSameDate(a.date!, b.date!)) return a.date!.compareTo(b.date!);

        if (a.startTime != null && b.startTime != null) {
          if (a.startTime == b.startTime) return a.title.compareTo(b.title);
          return a.startTime!.compareTo(b.startTime!);
        }

        if (a.startLesson != null && b.startLesson != null) {
          if (a.startLesson == b.startLesson) return a.title.compareTo(b.title);
          return a.startLesson!.compareTo(b.startLesson!);
        }
        if (a.startLesson != null) return -1;
        if (b.startLesson != null) return 1;
      }
      return 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SPListContainer(
      addEventSelectedDate: date,
      onSwipeLeft: onSwipeLeft,
      onSwipeRight: onSwipeRight,
      showBorder: lessons != null,
      showAddEventButton: mode == SPDisplayMode.yourPlan,
      child: () {
        if (lessons == null || lessons!.isEmpty) {
          final infoText = Text(
            lessons == null ? (isOnline != false ? "Keine Daten verfügbar." : "Keine Verbindung zum Server.")
              : "${getDayDescription(date)} kein Unterricht${mode == SPDisplayMode.roomPlan ? " in diesem Raum" : mode == SPDisplayMode.classPlan ? " in dieser Klasse" : ""}.",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: lessons == null ? hasDarkTheme(context) ? Colors.red.shade300 : Colors.red.shade800 : null),
          );
          if (events == null || events!.isEmpty) {
            return Center(child: infoText);
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.separated(
                itemCount: (events?.length ?? 0) + 2,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return infoText;
                  } else if (i == 1) {
                    return Text(
                      "Events ${getDayDescription(date).toLowerCase()}:",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    );
                  } else {
                    return CustomEventDisplay(events![i - 2], i > 2 ? events![i - 3].startLesson ?? -1 : -1);
                  }
                },
                separatorBuilder: (_, __) => const Divider(),
              ),
            );
          }
        }
        final stdata = Provider.of<StuPlanData>(context, listen: false);

        final mixedList = <Object>[...lessons!];
        int hourAt(int i) {
          final o = mixedList[i];
          if (o is CustomEvent) return o.startLesson ?? 1000;
          if (o is VPLesson) return o.schoolHour;
          return 1000;
        }
        /// Events werden nur im persönlichen Stundenplan angezeigt
        if (mode == SPDisplayMode.yourPlan && events != null && events!.isNotEmpty) {
          var insI = 0;
          var lastHr = 0;
          // var lastStartIns = 0;
          for (final evt in events!) {
            if (evt.startLesson == null) {
              // mixedList.insert(lastStartIns, evt);
              // lastStartIns++;
              mixedList.add(evt);
              continue;
            }
            if (lastHr > 0 && evt.startLesson == lastHr) {
              mixedList.insert(insI, evt);
              insI++;
            } else {
              while (insI < mixedList.length && hourAt(insI) <= evt.startLesson!) {
                insI++;
              }
              lastHr = evt.startLesson!;
              mixedList.insert(insI, evt);
              insI++;
            }
          }
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.separated(
              itemCount: mixedList.length + (extraScrollSpace != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == mixedList.length) return SizedBox(height: extraScrollSpace);

                final entry = mixedList[index];
                final prevHour = index > 0 ? (){
                  final p = mixedList[index - 1];
                  return (p is VPLesson) ? p.schoolHour : (p is CustomEvent) ? (p.startLesson ?? -1) : -1;
                }() : null;

                if (entry is VPLesson) {
                  return LessonDisplay(
                    entry,
                    prevHour,
                    fullLessonListForDate != null ? entry.hasLastRoomUsageFromList(fullLessonListForDate!) : false,
                    subject: stdata.availableSubjects[className]
                        ?.cast<VPCSubjectS?>()
                        .firstWhere(
                          (s) => s!.subjectID == entry.subjectID,
                          orElse: () => null,
                        ),
                    classNameToStrip: className,
                  );
                } else if (entry is CustomEvent) {
                  return CustomEventDisplay(entry, prevHour);
                } else {
                  return SizedBox.shrink();
                }
              },
              separatorBuilder: (context, index) => index < mixedList.length - 1 ? const Divider(height: 24) : const SizedBox.shrink(),
            ),
          ),
        );
      }(),
    );
  }
}

/// zeigt Stunde schön formatiert an (mit Dialog beim Antippen)
class LessonDisplay extends StatelessWidget {
  /// anzuzeigende Stunde
  final VPLesson lesson;
  /// Stunde der vorherigen Stunde (damit Text mit Stunde nur einmal vor mehreren Stunden in derselben Stunde
  /// angezeigt wird)
  final int? previousLessonHour;
  /// soll der Info-Dialog beim Antippen angezeigt werden?
  final bool showInfoDialog;
  /// das zur Stunde zugehörige Fach, für Anzeige von "sonst <Lehrer>" und "sonst <Fach>" bei Änderungen
  final VPCSubjectS? subject;
  /// Teil des Fachnamens der Stunde, der entfernt werden soll
  /// weil manche Stunden z.B. als 11DE1 eingetragen sind -> "11" wird entfernt
  final String? classNameToStrip;
  /// wird der Raum das letzte Mal für den Tag verwendet?
  final bool lastRoomUsageInDay;

  const LessonDisplay(this.lesson, this.previousLessonHour, this.lastRoomUsageInDay,
      {super.key, this.showInfoDialog = true, this.subject, this.classNameToStrip});

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
            builder: (dialogCtx) => generateLessonInfoDialog(dialogCtx, lesson, subject, classNameToStrip, lastRoomUsageInDay),
          ) : null,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 26,
                    child: (previousLessonHour != lesson.schoolHour)
                        ? Text("${lesson.schoolHour}. ")
                        : const SizedBox.shrink(),
                  ),
                ),
                Text(
                  lesson.subjectCode.replaceFirst(classNameToStrip ?? "funny joke.", ""),
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
                if (lastRoomUsageInDay && Provider.of<Preferences>(context, listen: false).stuPlanShowLastRoomUsage) Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    enableTapToDismiss: true,
                    triggerMode: TooltipTriggerMode.tap,
                    message: lesson.roomCodes.length == 1 ? "laut Plan letzte Verwendung des Raumes" : "laut Plan letzte Verwendung einer der gelisteten Räume",
                    showDuration: const Duration(seconds: 2),
                    child: Icon(Icons.last_page, size: 20, color: hasDarkTheme(context) ? Colors.white : Colors.black),
                  ),
                ),
                Text(
                  lesson.roomCodes.join(", "),
                  style: TextStyle(
                    color: (lesson.roomChanged) ? Colors.red : null,
                    fontWeight: (lesson.roomChanged) ? FontWeight.bold : FontWeight.w500,
                    // decoration: (lastRoomUsageInDay) ? TextDecoration.underline : null,
                    // decorationThickness: (lastRoomUsageInDay) ? 1.5 : null,
                  ),
                ),
              ],
            ),
            if (lesson.infoText != "")
              Row(
                children: [
                  const SizedBox(width: 25 + 4),
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

/// wie LessonDisplay, aber für Klausur
class ExamDisplay extends StatelessWidget {
  /// anzuzeigende Klausur
  final VPExam exam;
  /// Jahrgang der vorherigen Klausur (damit JG-Text nur einmal angezeigt wird)
  final String? previousYear;

  const ExamDisplay({super.key, required this.exam, required this.previousYear});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontSize: 18,
        height: 0,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showDialog(
                context: context,
                builder: (dialogCtx) => generateExamInfoDialog(dialogCtx, exam)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 70,
                  child: (previousYear != exam.year)
                      ? Text("JG ${exam.year}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20))
                      : const SizedBox.shrink(),
                ),
                SizedBox(width: 30, child: Text("${exam.hour}. ")),
                Text(
                  exam.subject,
                ),
                const Spacer(),
                Text("bei ${exam.teacher}", style: const TextStyle(fontSize: 16)),
              ],
            ),
            if (exam.info != "")
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 25),
                  Flexible(
                    child: Text(
                      exam.info,
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

// boah. mehr als 1600 Zeilen "Code".
