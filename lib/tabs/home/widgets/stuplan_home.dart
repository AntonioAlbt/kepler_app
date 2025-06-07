// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2023-2025 Antonio Albert

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
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';
import 'package:kepler_app/tabs/hourtable/hourtable.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';
import 'package:provider/provider.dart';

/// Widget, was aktuelle Vertretungen für heute oder morgen (je nach Uhrzeit) anzeigt und Stundenplan aktualisiert
/// 
/// (wahrscheinlich eines der besten Widgets, das die App anbietet)
class HomeStuPlanWidget extends StatefulWidget {
  final String id;

  const HomeStuPlanWidget({super.key, required this.id});

  @override
  State<HomeStuPlanWidget> createState() => HomeStuPlanWidgetState();
}

/// eindeutig eine der besten Funktionen im ganzen Code (commited um 01:26 Uhr lol)
///
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
        final date = shouldGoToNextPlanDay(context) ? DateTime.now().add(const Duration(days: 1)) : DateTime.now();
        return HomeWidgetBase(
          id: widget.id,
          title: Text("${shouldGoToNextPlanDay(context) ? "Morgige" : "Heutige"} Vertretungen"),
          color: colorWithLightness(keplerColorOrange, hasDarkTheme(context) ? .2 : .8),
          titleColor: colorWithLightness(keplerColorOrange, hasDarkTheme(context) ? .05 : .9),
          child: Column(
            children: [
              /// ist der Benutzer nicht angemeldet? -> Infotext und Knopf für Anmeldung 
              if (user == UserType.nobody) Padding(
                padding: const EdgeInsets.only(top: 0, left: 8, right: 8, bottom: 8),
                child: SPListContainer(
                  color: colorWithLightness(keplerColorOrange.withValues(alpha: .75), hasDarkTheme(context) ? .025 : .9),
                  shadow: false,
                  padding: EdgeInsets.zero,
                  showBorder: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          "${sie ? "Sie sind" : "Du bist"} nicht angemeldet. Bitte ${sie ? "melden Sie sich" : "melde Dich"} an, um auf den Stundenplan zuzugreifen.",
                          textAlign: TextAlign.center,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ElevatedButton(
                            onPressed: () => showLoginScreenAgain(clearData: false),
                            child: const Text("Jetzt anmelden"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              /// ist der Benutzer angemeldet und hat den Stundenplan schon eingerichtet?
              else if (!shouldShowStuPlanIntro(stdata, user == UserType.teacher)) SizedBox(
                height: 200,
                child: (user == UserType.pupil || user == UserType.parent) ? FutureBuilder(
                  future: (creds.vpPassword != null) ? IndiwareDataManager.getKlDataForDate(
                    date,
                    // DateTime(2025, 2, 6),
                    creds.vpHost!,
                    creds.vpUser!,
                    creds.vpPassword!,
                    forceRefresh: forceRefresh ?? false,
                  ) : Future<(VPKlData?, bool)>.error("welp"),
                  initialData: null,
                  builder: (context, datasn) {
                    forceRefresh = false;
                    var dataP = datasn.data;
                    if (datasn.error != null) {
                      if (creds.lernSaxLogin == lernSaxDemoModeMail) {
                        dataP = (const VPKlData(
                          additionalInfo: [],
                          classes: [VPClass(className: "Demo", hourBlocks: [], courses: [], subjects: [], lessons: [
                            VPLesson(schoolHour: 1, startTime: null, endTime: null, subjectCode: "De", subjectChanged: true, teacherCode: "Kol", teacherChanged: true, roomCodes: ["404"], roomChanged: false, subjectID: 1, infoText: "Mathe fällt aus")
                          ])],
                          header: VPHeader(lastUpdated: "", dataDate: "", filename: ""),
                          holidays: VPHolidays(holidayDateStrings: []),
                        ), true);
                      } else {
                        return const Text("Fehler beim Laden der Daten.");
                      }
                    }
                    final lessons = dataP?.$1?.classes.cast<VPClass?>().firstWhere((cl) => cl!.className == stdata.selectedClassName, orElse: () => null)
                      ?.lessons.where((l) => l.roomChanged || l.subjectChanged || l.teacherChanged || l.infoText != "")
                      .where((e) => !stdata.hiddenCourseIDs.contains(e.subjectID)).toList();
                    return SPWidgetList(
                      stillLoading: datasn.connectionState != ConnectionState.done,
                      lessons: lessons,
                      fullLessonList: dataP?.$1?.classes.cast<VPClass?>().firstWhere((cl) => cl!.className == stdata.selectedClassName, orElse: () => null)
                        ?.lessons,
                      onRefresh: () => setState(() => forceRefresh = true),
                      isOnline: dataP?.$2 ?? false,
                      isSchoolHoliday: stdata.checkIfHoliday(date),
                    );
                  }
                /// ist der Benutzer ein Lehrer? -> Vertretungen für Lehrer anzeigen
                ) : (user == UserType.teacher) ? FutureBuilder(
                  future: IndiwareDataManager.getLeDataForDate(
                    date,
                    creds.vpHost!,
                    creds.vpUser!,
                    creds.vpPassword!,
                    forceRefresh: forceRefresh ?? false,
                  ),
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
                      fullLessonList: data?.$1?.teachers.firstWhere((t) => t.teacherCode == stdata.selectedTeacherName)
                        .lessons,
                      onRefresh: () => setState(() => forceRefresh = true),
                      isOnline: data?.$2 ?? false,
                      isSchoolHoliday: stdata.checkIfHoliday(date),
                    );
                  },
                /// nicht erreichbar
                ) : const Text("Fehler."),
              /// hat der Benutzer den Stundenplan noch nicht eingerichtet? -> Info und Knopf dazu anzeigen
              ) else Padding(
                padding: const EdgeInsets.only(top: 0, left: 8, right: 8, bottom: 8),
                child: SPListContainer(
                  color: colorWithLightness(keplerColorOrange.withValues(alpha: .75), hasDarkTheme(context) ? .025 : .9),
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

  @override
  void initState() {
    super.initState();

    // listening to changes (especially to AppState.userType) would seem to make sense here,
    // but the user has to setup the stuplan anyway if they just completed the introduction
    // so they will have to reload the state anyway
    final prefs = Provider.of<Preferences>(context, listen: false);
    final state = Provider.of<AppState>(context, listen: false);
    // also check here, because it's shown on the home page
    if (
      !shouldShowStuPlanIntro(Provider.of<StuPlanData>(context, listen: false), state.userType == UserType.teacher) &&
      prefs.reloadStuPlanAutoOnceDaily
    ) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (shouldStuPlanAutoReload(context)) {
          setState(() => forceRefresh = true);
          Provider.of<InternalState>(context, listen: false).lastStuPlanAutoReload = DateTime.now();
        }
      });
    }
  }
}

/// Darstellung der geänderten Stunden speziell in diesem Widget
class SPWidgetList extends StatelessWidget {
  /// geänderte Stunden -> werden angezeigt
  final List<VPLesson>? lessons;
  /// kompletter Stundenplan des Tages (wird anscheinend nicht mal mehr verwendet)
  final List<VPLesson>? fullLessonList;
  /// wird aufgerufen, wenn der Benutzer Aktualisieren-Icon antippt
  final VoidCallback? onRefresh;
  /// wird der Plan noch geladen
  final bool stillLoading;
  /// war die Verbindung zum Server erfolgreich
  final bool isOnline;
  /// ist der anzuzeigende Tag ein freier Tag
  final bool isSchoolHoliday;
  const SPWidgetList({super.key, required this.lessons, this.fullLessonList, this.onRefresh, this.stillLoading = false, this.isOnline = false, required this.isSchoolHoliday});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 0, left: 8, right: 8, bottom: 8),
      child: SPListContainer(
        color: colorWithLightness(keplerColorOrange.withValues(alpha: .75), hasDarkTheme(context) ? .025 : .9),
        shadow: false,
        padding: EdgeInsets.zero,
        showBorder: false,
        // could've used a builder here, but whatever - it's just a bit less readable this way
        child: () {
          Widget? child;
          /// Falls heute WE ist und nicht zu morgen weitergrblättert werden soll
          if (evrydayIsSaturday() && !shouldGoToNextPlanDay(context)) {
            child = const Expanded(
              child: Center(
                child: Text(
                  "Heute ist Wochenende! 😃",
                  style: TextStyle(fontSize: 17),
                ),
              ),
            );
          } else if (isSchoolHoliday) {
            child = const Expanded(
              child: Center(
                child: Text(
                  "Heute ist keine Schule.",
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
                /// entweder this.child oder Standard-Stundenliste
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
                        false,
                        date: shouldGoToNextPlanDay(context) ? DateTime.now().add(const Duration(days: 1)) : DateTime.now(),
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
