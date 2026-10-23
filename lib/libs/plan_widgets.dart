// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2026 Jakob Krause

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


import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/watch_sync.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:provider/provider.dart';
import 'package:xml/xml.dart';

// Plandaten für die Stundenplan-Widgets: das Android-Homescreen-Widget (YourPlanWidget.kt), die
// iOS-Widgets (Sperrbildschirm + Homescreen) und - über ios/Runner/WatchSyncBridge.swift - die
// Apple Watch. Datenformat, Laden und Aktualisieren sind auf beiden Plattformen gleich.
// Plattformabhängig sind nur das Neuladen der Widgets ([_reloadWidgets]), die gespeicherte
// Planauswahl ([_savePlanSelection]) und der nächste Schultag, den nur iOS teilt.

/// App-Group-ID für den geteilten Speicher zwischen App und iOS-Widget-Extension (Sperrbildschirm-
/// und Homescreen-Widgets). Muss mit der App-Group in den Entitlements übereinstimmen
/// (u.a. ios/Runner/Runner.entitlements und ios/KeplerLockWidget/KeplerLockWidget.entitlements).
const iosWidgetAppGroupId = "group.de.kepler-chemnitz.keplerapp";

/// `kind` aller iOS-Widgets - jedes muss einzeln neu geladen werden
const _iosWidgetKinds = [
  "KeplerLockWidget",
  "KeplerNextLockWidget",
  "KeplerCurrentWidget",
  "KeplerNextWidget",
  "KeplerDayWidget",
];

/// wandelt eine Stunde in die Map-Form um, die die Widgets lesen. `start`/`end` (Format "HH:mm")
/// brauchen nur die iOS-Widgets, die daraus selbst die aktuelle bzw. nächste Stunde berechnen - das
/// Android-Widget ignoriert sie.
Map<String, dynamic> lessonToWidgetMap(VPLesson l) => {
      "schoolHour": l.schoolHour,
      "subject": l.subjectCode,
      "rooms": l.roomCodes,
      "teacher": l.teacherCode,
      "info": l.infoText,
      "start": l.startTime?.toString(),
      "end": l.endTime?.toString(),
      "changed": {
        "subject": l.subjectChanged,
        "rooms": l.roomChanged,
        "teacher": l.teacherChanged,
      },
    };

/// merkt sich während einer Aktualisierung, ob die Online-Abfragen den Server erreicht haben - nur
/// dann gilt die Drosselung in [updatePlanWidgets] als erfüllt
class _FetchState {
  bool attemptedOnline = false;
  bool failedOnline = false;

  bool get onlineSucceeded => attemptedOnline && !failedOnline;
}

/// zuletzt online abgefragte Pläne dieses Isolates (Schlüssel: Datum im Format des Plan-Caches).
/// Siehe [_loadDay], warum die Widgets dafür nicht den Plan-Cache der App verwenden.
final _onlineKlData = <String, VPKlData>{};
final _onlineLeData = <String, VPLeData>{};

/// fragt einen Plan online ab, ohne ihn irgendwo zu speichern. `null`, wenn es keinen Plan gibt
/// oder die Abfrage fehlschlägt (dann in [state] vermerkt).
Future<T?> _fetchOnline<T>(
  Future<(XmlDocument?, bool)> Function() fetch,
  T Function(XmlDocument) parse,
  _FetchState state,
) async {
  state.attemptedOnline = true;
  try {
    final (xml, online) = await fetch();
    if (!online) state.failedOnline = true;
    return xml == null ? null : parse(xml);
  } catch (e, s) {
    // z.B. falsche Zugangsdaten (401) oder ungültiges XML
    state.failedOnline = true;
    logCatch("widget-data", e, s);
    return null;
  }
}

/// lädt einen Tagesplan für die Widgets.
///
/// Schreibt bewusst NIE in den Plan-Cache der App (IndiwareDataManager): Die Stundenplan-
/// Benachrichtigungen (getDifferentClassLessons/getDifferentTeacherLessons in tasks.dart) erkennen
/// Änderungen, indem sie Online-Daten mit diesem Cache vergleichen. Würden die Widgets ihn vorher
/// mit frischen Daten überschreiben, gäbe es nichts mehr zu vergleichen und die Benachrichtigung
/// bliebe aus. Online abgefragte Pläne werden deshalb nur im Speicher ([memory]) gehalten.
///
/// Mit [forceRefresh] wird zuerst online abgefragt. Sonst - oder wenn die Abfrage fehlschlägt bzw.
/// keinen Plan liefert - wird zuerst der zuletzt online abgefragte Plan aus [memory] genommen, dann
/// der Plan-Cache der App gelesen. Der Speicher hat Vorrang, weil er aus der letzten erfolgreichen
/// Online-Abfrage der Widgets in diesem Isolate stammt. Der Cache wird dagegen nur geschrieben, wenn
/// die App einen Plan lädt (IndiwareDataManager.getKlDataForDate/getLeDataForDate), und im
/// Hintergrund von der Stundenplan-Benachrichtigung - dort aber nur für Klassenpläne
/// (getDifferentClassLessons; getDifferentTeacherLessons liest den Lehrer-Cache nur). Er ist deshalb
/// meist älter, kann aber auch neuer sein. Ist lokal gar nichts vorhanden, wird ohne [forceRefresh]
/// einmal online abgefragt.
Future<T?> _loadDay<T>({
  required DateTime date,
  required bool forceRefresh,
  required _FetchState state,
  required Map<String, T> memory,
  required Future<(XmlDocument?, bool)> Function() fetch,
  required T Function(XmlDocument) parse,
  required Future<T?> Function() readCache,
}) async {
  final key = IndiwareDataManager.fnTimeFormat.format(date);
  if (forceRefresh) {
    final online = await _fetchOnline(fetch, parse, state);
    if (online != null) return memory[key] = online;
  }
  final local = memory[key] ?? await readCache();
  if (local != null || forceRefresh) return local;
  final online = await _fetchOnline(fetch, parse, state);
  if (online != null) memory[key] = online;
  return online;
}

/// Schülerplan für [date] - siehe [_loadDay]
Future<VPKlData?> _klData(DateTime date, CredentialStore creds, bool forceRefresh, _FetchState state) =>
    _loadDay(
      date: date,
      forceRefresh: forceRefresh,
      state: state,
      memory: _onlineKlData,
      fetch: () => getKlXMLForDate(creds.vpHost!, creds.vpUser!, creds.vpPassword!, date),
      parse: xmlToKlData,
      readCache: () => IndiwareDataManager.getCachedKlDataForDate(date),
    );

/// Lehrerplan für [date] - siehe [_loadDay]
Future<VPLeData?> _leData(DateTime date, CredentialStore creds, bool forceRefresh, _FetchState state) =>
    _loadDay(
      date: date,
      forceRefresh: forceRefresh,
      state: state,
      memory: _onlineLeData,
      fetch: () => getLeXMLForDate(creds.vpHost!, creds.vpUser!, creds.vpPassword!, date),
      parse: xmlToLeData,
      readCache: () => IndiwareDataManager.getCachedLeDataForDate(date),
    );

/// baut die `plans`-Liste für einen bestimmten Tag: pro Plan eine Liste aus dem Namen (Lehrerkürzel
/// bzw. Klasse) gefolgt von den Stunden. `plans[0]` ist der primär ausgewählte Plan.
/// Gibt `null` zurück, wenn keine Daten abgefragt werden konnten.
///
/// Fehlt ein ausgewählter Lehrer bzw. eine ausgewählte Klasse in den Tagesdaten, wird der Plan
/// trotzdem - ohne Stunden - unter seinem Namen eingetragen: Die Widgets wählen ihren Plan über
/// den Namen aus und nehmen sonst `plans[0]`. Ein übersprungener Plan würde dort also stillschweigend
/// durch einen anderen ersetzt, ein leerer zeigt dagegen "Kein Plan".
Future<List<List<dynamic>>?> _buildPlansForDate(DateTime date, StuPlanData stdata,
    CredentialStore creds, Preferences prefs, bool teacher, bool forceRefresh, _FetchState state) async {
  final plans = <List<dynamic>>[];
  if (teacher) {
    final teacherName = stdata.selectedTeacherName;
    if (teacherName == null) return null;
    final data = await _leData(date, creds, forceRefresh, state);
    if (data == null) return null;
    final lessons =
        data.teachers.where((t) => t.teacherCode == teacherName).firstOrNull?.lessons ?? const [];
    plans.add([teacherName, ...lessons.map(lessonToWidgetMap)]);
  }
  final names = teacher
      ? stdata.altSelectedClassNames
      : [stdata.selectedClassName, ...stdata.altSelectedClassNames];
  if (names.isNotEmpty) {
    final data = await _klData(date, creds, forceRefresh, state);
    if (data == null) return null;
    for (int i = 0; i < names.length; i++) {
      final name = names[i];
      if (name == null) continue;
      // direkt die eben angelegte Liste befüllen - ein aus `i` berechneter Index in `plans`
      // stimmt nicht mehr, sobald oben ein Name übersprungen wurde
      final plan = <dynamic>[name];
      plans.add(plan);
      final lessons =
          data.classes.where((c) => c.className == name).firstOrNull?.lessons ?? const <VPLesson>[];
      // `i` bezieht sich weiterhin auf `names` und passt damit zu den Indizes der Ausblendungen
      final hidden = (teacher || i >= 1)
          ? stdata.getAltHiddenCourseIDs(teacher ? i : i - 1)
          : stdata.hiddenCourseIDs;
      plan.addAll(lessons
          .where((t) => !hidden.any((id) => t.subjectID == id))
          .map(lessonToWidgetMap));
      if (lessons.any((l) => hidden.any((id) => id == l.subjectID)) &&
          prefs.showLessonsHiddenInfo) {
        plan.add({"hidden": true});
      }
    }
  }
  return plans;
}

/// Samstag oder Sonntag (wie keplerIsWeekend in den iOS-Widgets bzw. die Wochenend-Prüfung in
/// YourPlanWidget.kt)
bool _isWeekend(DateTime d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

/// nächster Schultag (Mo–Fr) nach [from]
DateTime _nextSchoolDay(DateTime from) {
  var d = DateTime(from.year, from.month, from.day).add(const Duration(days: 1));
  while (_isWeekend(d)) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

/// ist überhaupt ein Plan ausgewählt, den [_buildPlansForDate] bauen würde? Lehrer: das
/// Lehrerkürzel, sonst die Klasse oder eine alternative Klasse.
bool _hasPlanSelection(StuPlanData stdata, bool teacher) => teacher
    ? stdata.selectedTeacherName != null
    : stdata.selectedClassName != null || stdata.altSelectedClassNames.isNotEmpty;

/// baut den Plan für [date] und speichert ihn unter [key] im Widget-Speicher. Liefert Indiware keinen
/// Plan, ist der Tag laut [StuPlanData.checkIfHoliday] aber frei (Feiertag/Ferien), wird ein leerer
/// Plan mit `holiday: true` gespeichert - so zeigen die Widgets "frei" statt "Plan veraltet" bzw.
/// "noch kein Plan". Sonst bleibt der bisherige Wert stehen.
///
/// Gibt `true` zurück, wenn etwas gespeichert wurde. Fehler werden geloggt, nicht weitergeworfen -
/// so verhindert ein Fehler bei einem Tag nicht die Aktualisierung des anderen.
Future<bool> _saveDay(String key, DateTime date, StuPlanData stdata, CredentialStore creds,
    Preferences prefs, bool teacher, bool forceRefresh, _FetchState state) async {
  try {
    final plans = await _buildPlansForDate(date, stdata, creds, prefs, teacher, forceRefresh, state);
    final holiday = stdata.checkIfHoliday(date);
    if (plans == null && !holiday) return false;
    final saved = await HomeWidget.saveWidgetData(
        key,
        jsonEncode({
          "date": DateFormat("dd-MM-yyyy").format(date),
          "holiday": holiday,
          "plans": plans ?? <List<dynamic>>[],
        }));
    return saved ?? false;
  } catch (e, s) {
    logCatch("widget-data", "Fehler beim Speichern der Widget-Daten ($key): $e", s);
    return false;
  }
}

/// Wert, der im Widget-Speicher für „kein Plan“ steht.
///
/// Auf iOS ist ein echtes Entfernen über home_widget 0.8.0 nicht möglich: `saveWidgetData(key, null)`
/// kommt dort als NSNull statt nil an, das Plugin versucht es zu speichern und die App stürzt ab
/// („Attempt to insert non-property list object null“). Ein leerer Text wirkt für alle iOS-Leser wie
/// ein fehlender Eintrag, weil sie ihn als JSON parsen (PlanStore, availablePlanNames, Uhr).
/// Auf Android entfernt `null` den Eintrag - einen leeren Text könnte YourPlanWidget.kt nicht als
/// JSON lesen.
final _noPlanValue = Platform.isIOS ? "" : null;

bool _isNoPlan(String? value) => value == null || value.isEmpty;

/// iOS: Key für die Namen aller ausgewählten Pläne als JSON-Liste, in derselben Reihenfolge wie
/// `plans` (primärer zuerst). Daraus füllt der Widget-Editor seine Planauswahl (availablePlanNames in
/// PlanSelection.swift). Bewusst getrennt von "data"/"data_next": An Wochenenden, Ferientagen oder
/// bevor ein Plan veröffentlicht ist, enthalten die keine Pläne - die Auswahl wäre dann leer.
const _planNamesKey = "plan_names";

/// Android: Name des AppWidgetReceivers (android/.../widgets/YourPlanWidgetReceiver.kt)
const _androidWidgetReceiver = "widgets.YourPlanWidgetReceiver";

/// Namen der ausgewählten Pläne in der Reihenfolge von `plans` (siehe [_buildPlansForDate])
List<String> _planNames(StuPlanData stdata, bool teacher) => [
      teacher ? stdata.selectedTeacherName : stdata.selectedClassName,
      ...stdata.altSelectedClassNames,
    ].whereType<String>().toList();

/// speichert, welche Pläne ausgewählt sind - daraus bieten die Widgets beim Einrichten ihre
/// Planauswahl an. Die Reihenfolge entspricht `plans` (siehe [_buildPlansForDate]).
///
/// Android: "plan_setup", "plans_avail" (durch "|" getrennt) und "teacher" für
/// YourPlanWidgetConfigActivity.kt. iOS: die Namen als JSON unter [_planNamesKey].
Future<void> _savePlanSelection(StuPlanData stdata, bool teacher) async {
  if (Platform.isAndroid) {
    final primary = teacher ? stdata.selectedTeacherName : stdata.selectedClassName;
    await HomeWidget.saveWidgetData("plan_setup", primary != null);
    if (primary == null) return;
    await HomeWidget.saveWidgetData("plans_avail", [primary, ...stdata.altSelectedClassNames].join("|"));
    await HomeWidget.saveWidgetData("teacher", teacher);
  } else {
    await HomeWidget.saveWidgetData<String>(_planNamesKey, jsonEncode(_planNames(stdata, teacher)));
  }
}

/// Gegenstück zu [_savePlanSelection]: kein Plan ausgewählt bzw. teilbar
Future<void> _removePlanSelection() async {
  if (Platform.isAndroid) {
    await HomeWidget.saveWidgetData("plan_setup", false);
  } else {
    await HomeWidget.saveWidgetData<String>(_planNamesKey, _noPlanValue);
  }
}

/// lädt alle Widgets neu. Auf iOS (Sperrbildschirm + Homescreen) wird zusätzlich die Übertragung an
/// die Uhr angestoßen.
///
/// Gibt `true` zurück, wenn alle Neulade-Aufrufe angenommen wurden. home_widget 0.8.0 ruft auf iOS
/// dafür nur `WidgetCenter.reloadTimelines(ofKind:)` auf und meldet danach immer `true` - auch für
/// nicht platzierte Widgets; ein Fehler kommt dort als Exception.
Future<bool> _reloadWidgets() async {
  if (Platform.isAndroid) {
    return (await HomeWidget.updateWidget(androidName: _androidWidgetReceiver)) ?? false;
  }
  var ok = true;
  for (final kind in _iosWidgetKinds) {
    ok = ((await HomeWidget.updateWidget(iOSName: kind)) ?? false) && ok;
  }
  // Die Uhr hat keinen Zugriff auf die App-Group des iPhones - sie braucht die Daten ausdrücklich
  // zugeschickt. Entprellt, siehe syncWatchSoon. Im Hintergrund-Task reicht das nicht (er endet vor
  // Ablauf der Entprellung) - dort überträgt runWidgetUpdateTask in tasks.dart zusätzlich sofort.
  syncWatchSoon();
  return ok;
}

/// leert "data", "data_next" und die Planauswahl im Widget-Speicher (siehe [_noPlanValue]) und lädt
/// die Widgets (und die Uhr) neu. Ist beides schon leer, passiert nichts - so löst nicht jeder Aufruf
/// ohne Zugangsdaten eine Übertragung an die Uhr aus.
Future<void> _removeWidgetData() async {
  final data = await HomeWidget.getWidgetData<String>("data");
  final next = await HomeWidget.getWidgetData<String>("data_next");
  if (_isNoPlan(data) && _isNoPlan(next)) return;
  await HomeWidget.saveWidgetData<String>("data", _noPlanValue);
  await HomeWidget.saveWidgetData<String>("data_next", _noPlanValue);
  await _removePlanSelection();
  await _reloadWidgets();
}

/// eigentliche Umsetzung von [savePlanWidgetData]; liefert zusätzlich, ob die Online-Abfragen
/// erfolgreich waren (für die Drosselung in [updatePlanWidgets])
Future<({bool ok, bool onlineSucceeded})> _savePlanWidgetData(
  StuPlanData stdata,
  CredentialStore creds,
  Preferences prefs,
  bool teacher,
  bool forceRefresh,
) async {
  final state = _FetchState();
  try {
    // ohne Zugangsdaten kann kein Plan abgefragt werden (z.B. vor Abschluss des Intros oder nach
    // dem Abmelden bzw. ungültig gewordenen Zugangsdaten). Dann auch die zuletzt geteilten Pläne
    // leeren (siehe _noPlanValue), damit Widgets und Uhr keinen Plan mehr zeigen.
    if (creds.vpHost == null || creds.vpUser == null || creds.vpPassword == null) {
      await _removeWidgetData();
      return (ok: false, onlineSucceeded: false);
    }

    // ohne ausgewählten Plan (z.B. im Intro zwischen Anmeldung und Klassenwahl, oder nachdem der
    // gewählte Lehrer aus den Schuldaten verschwunden ist) gibt es nichts abzufragen. Keinen leeren
    // Plan schreiben, sondern die zuletzt geteilten Pläne leeren - sie gehören zu keiner
    // aktuellen Auswahl mehr; die Widgets zeigen dann keinen Plan.
    if (!_hasPlanSelection(stdata, teacher)) {
      await _removeWidgetData();
      return (ok: false, onlineSucceeded: false);
    }

    await _savePlanSelection(stdata, teacher);

    final today = DateTime.now();
    final todayKey = IndiwareDataManager.fnTimeFormat.format(today);
    // Pläne vergangener Tage werden nicht mehr gebraucht
    _onlineKlData.removeWhere((k, _) => k.compareTo(todayKey) < 0);
    _onlineLeData.removeWhere((k, _) => k.compareTo(todayKey) < 0);

    // heutiger Plan. Am Wochenende gibt es keinen - der Server liefert dann keinen Plan (404), und die
    // Abfrage kostet Zeit, die im Hintergrund-Task knapp ist. Deshalb am Wochenende nicht abfragen;
    // ein stehengebliebener Freitagsplan schadet nicht, weil die Widgets das Datum prüfen und ab
    // Montag "data_next" nehmen (iOS) bzw. "Wochenende" zeigen (Android), bis "data" wieder
    // geschrieben wird.
    // Beide Tage sind getrennt abgesichert, damit ein Fehler bei einem Tag den anderen nicht
    // verhindert.
    final savedToday = !_isWeekend(today) &&
        await _saveDay("data", today, stdata, creds, prefs, teacher, forceRefresh, state);
    // iOS: zusätzlich den nächsten Schultag teilen, damit die Widgets und die Uhr abends bzw. am
    // Wochenende schon dessen Plan zeigen können. Das Android-Widget zeigt nur den heutigen Plan -
    // dort wäre das nur eine weitere Abfrage.
    final savedNext = Platform.isIOS &&
        await _saveDay(
            "data_next", _nextSchoolDay(today), stdata, creds, prefs, teacher, forceRefresh, state);

    final reloaded = await _reloadWidgets();
    return (ok: (savedToday || savedNext) && reloaded, onlineSucceeded: state.onlineSucceeded);
  } catch (e, s) {
    logCatch("widget-data", "Fehler beim Speichern der Widget-Daten: $e", s);
    return (ok: false, onlineSucceeded: state.onlineSucceeded);
  }
}

/// Ermittelt den (Vertretungs-)Plan für heute ("data") und - nur iOS - den nächsten Schultag
/// ("data_next") für den ausgewählten Lehrer bzw. die ausgewählten Klassen und speichert ihn über
/// `home_widget` im Widget-Speicher (iOS: App-Group). Danach werden alle Widgets neu geladen, auf iOS
/// wird außerdem die Übertragung an die Uhr angestoßen.
///
/// `plans` enthält alle ausgewählten Pläne (primärer zuerst); welchen davon ein Widget zeigt, wählt
/// der Nutzer in der Widget-Konfiguration (iOS-Standard: `plans[0]`). Die aktuelle/nächste Stunde
/// berechnen die iOS-Widgets selbst anhand der `start`/`end`-Zeiten.
///
/// Der Plan-Cache der App wird dabei nur gelesen, nie geschrieben (Grund siehe [_loadDay]).
///
/// [forceRefresh]: Plan zuerst online abfragen (mit Rückfall auf den zuletzt online abgefragten Plan
/// bzw. den Cache, falls die Abfrage fehlschlägt). Ohne wird nur online abgefragt, wenn lokal noch
/// nichts für den Tag vorliegt.
///
/// Fehlen die Zugangsdaten oder ist kein Plan ausgewählt, werden "data", "data_next" und die
/// Planauswahl geleert (z.B. nach dem Abmelden) und nichts abgefragt. Am Wochenende wird "data"
/// nicht abgefragt.
///
/// Gibt `true` zurück, wenn mindestens ein Tag gespeichert und die Widgets neu geladen wurden.
/// Schlägt nie mit einer Exception fehl, sondern gibt im Fehlerfall `false` zurück.
Future<bool> savePlanWidgetData(
  StuPlanData stdata,
  CredentialStore creds,
  Preferences prefs,
  bool teacher, {
  bool forceRefresh = false,
}) async =>
    (await _savePlanWidgetData(stdata, creds, prefs, teacher, forceRefresh)).ok;

/// Sollen die Widgets den Lehrerplan (statt der Klassenpläne) zeigen?
///
/// Maßgeblich ist der Nutzertyp. Steht er nicht fest ([UserType.nobody], z.B. wenn LernSax beim
/// Start nicht erreichbar war und noch kein Nutzertyp gespeichert ist, oder die LernSax-Zugangsdaten
/// ungültig geworden sind, die Stundenplan-Zugangsdaten aber nicht), gilt dieselbe Regel wie im
/// iOS-Hintergrund-Task (runWidgetUpdateTask in tasks.dart, der keinen Nutzertyp kennt): Lehrerplan,
/// sobald ein Lehrer ausgewählt ist. Sonst teilte die App in diesem Fall die Klassenpläne und der
/// Hintergrund-Task danach den Lehrerplan - die Widgets sprängen zwischen beiden hin und her.
/// Ein reines `userType == UserType.teacher` würde in diesem Fall außerdem einen Klassenplan
/// suchen, obwohl nur ein Lehrer ausgewählt ist.
bool widgetTeacherMode(UserType userType, StuPlanData stdata) => switch (userType) {
      UserType.teacher => true,
      UserType.nobody => stdata.selectedTeacherName != null,
      UserType.pupil || UserType.parent => false,
    };

/// Mindestabstand zwischen zwei Online-Abfragen für die Widgets aus der laufenden App heraus
const widgetRefreshInterval = Duration(minutes: 15);

/// Zeitpunkt der letzten erfolgreichen Online-Abfrage aus der laufenden App
DateTime? _lastOnlineRefresh;
Future<bool>? _runningUpdate;

/// Aktualisiert die Widget-Daten aus der laufenden App (Start, Zurückholen aus dem Hintergrund,
/// Öffnen von "Dein Stundenplan", geänderte Planauswahl).
///
/// Online wird höchstens alle [widgetRefreshInterval] abgefragt, sonst lokal gelesen (siehe
/// [savePlanWidgetData]). Frische Daten beim Start und Zurückholen sind sinnvoll, weil die Widgets
/// sonst nur im Hintergrund aktualisiert werden - auf iOS selten und unvorhersehbar, auf Android
/// gar nicht. Die Drosselung verhindert,
/// dass jedes kurze Wechseln in die App Netzwerkanfragen auslöst. Als Zeitpunkt zählt nur eine
/// erfolgreiche Online-Abfrage - schlägt sie fehl (z.B. offline), wird beim nächsten Aufruf erneut
/// online abgefragt.
///
/// Läuft bereits eine Aktualisierung (z.B. App-Start und gleichzeitig Öffnen des Stundenplans), wird
/// deren Ergebnis zurückgegeben statt eine zweite zu starten.
///
/// [selectionChanged]: nach einer Änderung der Planauswahl (Klassen, Lehrer, ausgeblendete Fächer).
/// Dann wird eine laufende Aktualisierung nicht übernommen - sie arbeitet evtl. noch mit der alten
/// Auswahl -, sondern danach neu aktualisiert, und zwar ohne Drosselung online.
Future<bool> updatePlanWidgets(
  StuPlanData stdata,
  CredentialStore creds,
  Preferences prefs,
  bool teacher, {
  bool selectionChanged = false,
}) {
  final running = _runningUpdate;
  if (running != null && !selectionChanged) return running;

  Future<bool> run() async {
    final start = DateTime.now();
    final last = _lastOnlineRefresh;
    final forceRefresh =
        selectionChanged || last == null || start.difference(last) >= widgetRefreshInterval;
    final result = await _savePlanWidgetData(stdata, creds, prefs, teacher, forceRefresh);
    if (forceRefresh && result.onlineSucceeded) _lastOnlineRefresh = start;
    return result.ok;
  }

  late final Future<bool> update;
  // erst nach einer laufenden Aktualisierung starten, damit deren (ältere) Daten nicht zuletzt
  // geschrieben werden. Deren Ergebnis ist hier egal; Fehler fängt sie selbst ab.
  update = (running == null ? run() : running.then((_) => run())).whenComplete(() {
    if (identical(_runningUpdate, update)) _runningUpdate = null;
  });
  _runningUpdate = update;
  return update;
}

/// [updatePlanWidgets] mit allem Nötigen aus [context] - nur synchron, also direkt im Callback
/// aufrufen, solange [context] noch eingehängt ist. [selectionChanged] nach einer Änderung der
/// Planauswahl (Lehrer auswählen, Fächer ausblenden, alternative Klasse hinzufügen/bearbeiten/
/// entfernen), siehe [updatePlanWidgets].
Future<bool> updatePlanWidgetsFrom(BuildContext context, {bool selectionChanged = false}) {
  final stdata = context.read<StuPlanData>();
  return updatePlanWidgets(
    stdata,
    context.read<CredentialStore>(),
    context.read<Preferences>(),
    widgetTeacherMode(context.read<AppState>().userType, stdata),
    selectionChanged: selectionChanged,
  );
}

/// Nach dem Abmelden: leert die geteilten Pläne ("data", "data_next"), damit Widgets und Uhr
/// keinen Plan mehr zeigen, und vergisst die zuletzt online abgefragten Pläne. Wartet vorher eine
/// laufende Aktualisierung ab, damit diese die Daten nicht danach wieder schreibt.
///
/// Schlägt nie mit einer Exception fehl.
Future<void> clearPlanWidgets() async {
  try {
    await _runningUpdate;
    _onlineKlData.clear();
    _onlineLeData.clear();
    _lastOnlineRefresh = null;
    await _removeWidgetData();
  } catch (e, s) {
    logCatch("widget-data", "Fehler beim Entfernen der Widget-Daten: $e", s);
  }
}
