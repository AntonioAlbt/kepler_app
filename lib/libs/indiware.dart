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

import 'dart:convert';

import 'package:enough_serialization/enough_serialization.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/tabs/about.dart';
import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;

/// Host ist zwar hier hardcoded, aber bei Änderung Achtung: App bevorzugt den von LernSax bei der Anmeldung
/// abgefragten Host
const baseUrl = "https://plan.kepler-chemnitz.de/stuplanindiware";
/// Host, der in der Demo-Version genutzt werden soll
/// (nicht für echte Anfragen, nur für Check auf Demo-Version)
const indiwareDemoHost = "demo";

/// Unterschied zwischen den Plänen:
/// - Desktopplan: bietet nur Ausfälle, Infos zu Klausuren
/// - Mobilplan: bietet kompletten Stundenplan inkl. Ausfällen
///     -> allgemeine Info-XML-Daten: letzte verfügbare Plan-Datei, vom Server ausgesucht
///       -> sichere Datenquelle für z.B. freie Tage oder verfügbare Klassen

/// Pfad zu Desktopplan für Schüler
const sUrlDPath = "/VplanonlineS";
/// Pfad zu Mobilplan für Schüler
const sUrlMPath = "/VmobilS";
/// Pfad zu allgemeiner Info-XML-Datei (hier: Klassen.xml) für Schüler
const sUrlMKlXmlPath = "$sUrlMPath/mobdaten/Klassen.xml";

/// Pfad zu Desktopdaten für Lehrer
const lUrlDPath = "/VplanonlineL";
/// Pfad zu Mobildaten für Schüler
const lUrlMPath = "/VmobilL";
/// Pfad zu allgemeiner Info-XML-Datei (hier: Lehrer.xml) für Lehrer
const lUrlMLeXmlPath = "$lUrlMPath/mobdaten/Lehrer.xml";

/// Klassen.xml-URL angepasst auf host
Uri sUrlMKlXmlUrl(String host) => Uri.parse("$host$sUrlMKlXmlPath");
/// Lehrer.xml-URL angepasst auf host
Uri lUrlMLeXmlUrl(String host) => Uri.parse("$host$lUrlMLeXmlPath");

/// Serialisierbares Objekt für extrem simple Uhrzeit (HH:MM)
class HMTime extends SerializableObject {
  int get hour => attributes["hour"];
  set hour(int val) => attributes["hour"] = val;

  int get minute => attributes["minute"];
  set minute(int val) => attributes["minute"] = val;

  /// DateTime aus Uhrzeit und Basis
  DateTime toDateTime(DateTime? dayBase) =>
      DateTime(dayBase?.year ?? 0, dayBase?.month ?? 1, dayBase?.day ?? 1, hour, minute);

  HMTime(int hour, int minute) {
    this.hour = hour;
    this.minute = minute;
  }

  HMTime.fromStrings(String hour, String minute) {
    this.hour = int.parse(hour);
    this.minute = int.parse(minute);
  }
  
  /// aus String mit Format HH:MM (bzw. H:M)
  HMTime.fromTimeString(String timeString) {
    hour = int.parse(timeString.split(':')[0]);
    minute = int.parse(timeString.split(':')[1]);
  }
  
  @override
  String toString() {
    return '${hour.toString().padLeft(2, "0")}:${minute.toString().padLeft(2, "0")}';
  }

  @override
  operator ==(Object other) {
    if (other is! DateTime) return false;
    return hashCode == other.hashCode;
  }

  @override
  int get hashCode => toString().hashCode;
}

/// Root-Objekt für Schülermobildaten
class VPKlData {
  /// aus Element `<Kopf>`
  final VPHeader header;
  /// aus Element `<FreieTage>`
  final VPHolidays holidays;
  /// aus Element `<Klassen>`
  final List<VPClass> classes;
  /// aus Inhalten der Unterelemente `<ZiZeile>` aus Element `<ZusatzInfo>`
  final List<String> additionalInfo;

  const VPKlData({required this.header, required this.holidays, required this.classes, required this.additionalInfo});
  @override
  String toString() {
    return 'VPKlData(header: $header, holidays: $holidays, classes: $classes, additionalInfo: $additionalInfo)';
  }
}

/// Root-Objekt für Lehrermobildaten
class VPLeData {
  /// aus Element `<Kopf>`
  final VPHeader header;
  /// aus Element `<FreieTage>`
  final VPHolidays holidays;
  /// aus Element `<Klassen>` (ist gleich benannt, obwohl es sich jetzt auf Lehrer bezieht)
  final List<VPTeacher> teachers;
  /// aus Inhalten der Unterelemente `<ZiZeile>` aus Element `<ZusatzInfo>`
  final List<String> additionalInfo;

  const VPLeData({required this.header, required this.holidays, required this.teachers, required this.additionalInfo});
  @override
  String toString() {
    return 'VPLeData(header: $header, holidays: $holidays, teacher: $teachers, additionalInfo: $additionalInfo)';
  }
}

class VPHeader {
  /// wann der Plan zuletzt auf dem Server geändert wurde - aus Element `<zeitstempel>`
  final String lastUpdated;
  /// für welchen Tag der Plan ist - aus Element `<DatumPlan>`
  final String dataDate;
  /// Dateiname des Planes (auf dem Server?) - aus Element `<dateiname>`
  final String filename;
  /// ungenutze Elemente: <planart>, <nativ>, <woche>, <tageprowoche>, <schulnummer>

  const VPHeader({required this.lastUpdated, required this.dataDate, required this.filename});
  @override
  String toString() {
    return 'VPHeader(lastUpdated: $lastUpdated, dataDate: $dataDate, filename: $filename)';
  }
}

class VPHolidays {
  /// Liste der freien Tage, direkt aus XML als String ausgelesen
  final List<String> holidayDateStrings;

  /// verarbeitete Liste der freien Tage
  List<DateTime> get holidayDates => holidayDateStrings
      .map(
        (holidayString) => DateTime(
          int.parse("20${holidayString.substring(0, 2)}"),
          int.parse(holidayString.substring(2, 4)),
          int.parse(holidayString.substring(4, 6)),
        ),
      ).toList();

  const VPHolidays({required this.holidayDateStrings});
  @override
  String toString() {
    return 'VPHolidays(holidayDates: ${holidayDates.map((e) => indiwareFilenameFormat.format(e))})';
  }
}

class VPClass {
  /// "Name" bzw. Kürzel der Klasse - aus Element `<Kurz>`
  final String className;
  /// ungenutzes Element: <Hash> (anscheinend immer leer)
  /// Zeitblöcke, in denen Stunden stattfinden können - aus Element `<KlStunden>`
  final List<VPHourBlock> hourBlocks;
  /// Kurse der Klasse? Nutzen/Bedeutung unklar (auch keine Verwendung) - aus Element `<Kurse>`
  final List<VPClassCourse> courses;
  /// Fächer/Kurse der Klasse mit Infos - aus Element `<Unterricht>`
  final List<VPClassSubject> subjects;
  /// echte Unterrichtsstunden an dem gegebenen Tag - aus Element `<Pl>`
  final List<VPLesson> lessons;

  const VPClass({required this.className, required this.hourBlocks, required this.courses, required this.subjects, required this.lessons});
  @override
  String toString() {
    return 'VPClass(className: $className, hourBlocks: $hourBlocks, courses: $courses, subjects: $subjects, lessons: $lessons)';
  }
}

/// aus Unterelement `<KlSt>` von VPClass
class VPHourBlock {
  /// Beginn der Stunde - aus Element `<ZeitVon>`
  final HMTime startTime;
  /// Ende der Stunde - aus Element `<ZeitBis>`
  final HMTime endTime;
  /// Inhalt des Elementes
  final int blockStartLesson;

  const VPHourBlock({required this.startTime, required this.endTime, required this.blockStartLesson});
  @override
  String toString() {
    return 'VPHourBlock(startTime: $startTime, endTime: $endTime, blockStartLesson: $blockStartLesson)';
  }
}

/// aus Unterelement `<KKz>` von `<Ku>`
class VPClassCourse {
  /// aus Element `<KLe>`
  final String? teacherCode;
  /// Inhalt des Elementes
  final String courseName;

  const VPClassCourse({required this.teacherCode, required this.courseName});
  @override
  String toString() {
    return 'VPClassCourse(teacherCode: $teacherCode, courseName: $courseName)';
  }
}

/// aus Unterelement `<UeNr>` von `<Ue>`
class VPClassSubject {
  /// aus Element `<UeLe>`
  final String teacherCode;
  /// aus Element `<UeFa>`
  final String subjectCode;
  // only sometimes defined, seems to include additional info about some subjects (usually the "courses")
  /// nur manchmal verwendet, mit umfangreicherer Beschreibung zu manchen Fächern -> meist Kurse in JG 11/12
  /// aus Element `<UeGr>`
  final String? additionalDescr;
  /// Inhalt des Elementes
  final int subjectID;

  const VPClassSubject({required this.teacherCode, required this.subjectCode, this.additionalDescr, required this.subjectID});
  @override
  String toString() {
    return 'VPClassSubject(teacherCode: $teacherCode, subjectCode: $subjectCode, additionalDescr: $additionalDescr, subjectID: $subjectID)';
  }
}

/// aus Unterelement `<Std>` von `<Pl>`
class VPLesson {
  /// aus Element `<St>`
  final int schoolHour;
  /// aus Element `<Beginn>`
  final HMTime? startTime;
  /// aus Element `<Ende>`
  final HMTime? endTime;
  /// aus Element `<Fa>`
  final String subjectCode;
  /// ist Attribut `<Fa>.FaAe == "FaGeaendert"`?
  final bool subjectChanged;
  /// aus Element `<Le>`
  final String teacherCode;
  /// ist Attribut `<Le>.LeAe == "LeGeaendert"`?
  final bool teacherChanged;
  /// aus Element `<Ra>`
  final List<String> roomCodes;
  /// ist Attribut `<Ra>.RaAe == "RaGeaendert"`?
  final bool roomChanged;
  /// aus Element `<Nr>`
  final int? subjectID;
  /// aus Element `<If>`
  final String infoText;
  
  // additional access method for better clarity in the code
  /// -> teacherCode
  String get teachingClassName => teacherCode;
  /// -> teacherChanged
  bool get teachingClassChanged => teacherChanged;

  const VPLesson({required this.schoolHour, required this.startTime, required this.endTime, required this.subjectCode, required this.subjectChanged, required this.teacherCode, required this.teacherChanged, required this.roomCodes, required this.roomChanged, required this.subjectID, required this.infoText});
  @override
  String toString() {
    return 'VPLesson(schoolHour: $schoolHour, startTime: $startTime, endTime: $endTime, subjectCode: $subjectCode, subjectChanged: $subjectChanged, teacherCode: $teacherCode, teacherChanged: $teacherChanged, roomCodes: $roomCodes, roomChanged: $roomChanged, subjectID: $subjectID, infoText: $infoText)';
  }

  VPLesson copyWith({
    int? schoolHour,
    HMTime? startTime,
    HMTime? endTime,
    String? subjectCode,
    bool? subjectChanged,
    String? teacherCode,
    bool? teacherChanged,
    List<String>? roomCodes,
    bool? roomChanged,
    int? subjectID,
    String? infoText,
  }) {
    return VPLesson(
      schoolHour: schoolHour ?? this.schoolHour,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      subjectCode: subjectCode ?? this.subjectCode,
      subjectChanged: subjectChanged ?? this.subjectChanged,
      teacherCode: teacherCode ?? this.teacherCode,
      teacherChanged: teacherChanged ?? this.teacherChanged,
      roomCodes: roomCodes ?? this.roomCodes,
      roomChanged: roomChanged ?? this.roomChanged,
      subjectID: subjectID ?? this.subjectID,
      infoText: infoText ?? this.infoText,
    );
  }

  /// warning! because lessons don't contain date information, this compares against all lessons in the list
  /// (not only lessons on the same date)
  /// also, because lessons can use multiple rooms, this checks all rooms against all rooms in all other lessons
  bool hasLastRoomUsageFromList(List<VPLesson> lessons) {
    if (roomCodes.contains("") || roomCodes.contains("---") || roomCodes.isEmpty) return false;
    // true if no lesson is after current lesson and also uses any of the current lessons rooms
    return !lessons.any((lesson) => lesson.schoolHour > schoolHour && roomCodes.any((rc) => lesson.roomCodes.contains(rc)));
  }
}

const cancellationALaLernSax = "Aufgaben in LernSax bearbeiten";

VPLesson considerLernSaxCancellationForLesson(VPLesson lesson, bool considerIt, {String roomOverride = ""}) {
  if (!considerIt) return lesson;
  if (lesson.subjectChanged || lesson.teacherCode != "") return lesson; // this might mean that the tasks are actually meant to be done in school
  if (!lesson.infoText.contains(cancellationALaLernSax)) return lesson;
  return lesson.copyWith(subjectCode: "---", subjectChanged: true, teacherCode: "", teacherChanged: true, roomCodes: (roomOverride == "") ? [] : [roomOverride], roomChanged: true, infoText: "für ${lesson.subjectCode}${lesson.teacherCode != "" ? " bei ${lesson.teacherCode}" : ""} ${lesson.infoText}");
}

class VPTeacher {
  /// Lehrerkürzel - aus Element `<Kurz>`
  final String teacherCode;
  /// ungenutzes Element: <Hash> (anscheinend immer leer)
  /// aus Element `<KlStunden>`
  final List<VPHourBlock> hourBlocks;
  /// aus Element `<Pl>`
  final List<VPLesson> lessons;
  /// aus Element `<Aufsichten>`
  final List<VPTeacherSupervision> supervisions;

  const VPTeacher({required this.teacherCode, required this.hourBlocks, required this.lessons, required this.supervisions});
  @override
  String toString() {
    return 'VPTeacher(teacherCode: $teacherCode, hourBlocks: $hourBlocks, lessons: $lessons, supervisions: $supervisions)';
  }
}

/// aus Unterelement `<Aufsicht>` von `<Aufsichten>`
class VPTeacherSupervision {
  /// aus Element `<AuVorStunde>`
  final int beforeSchoolHour;
  /// aus Element `<AuUhrzeit>`
  final HMTime time;
  /// aus Element `<AuZeit>`
  final String timeDesc;
  /// aus Element `<AuOrt>`
  final String location;
  /// aus Element `<AuInfo>`
  final String? infoText;
  /// ist Attribut `<Aufsicht>.AuAe == "AuAusfall"`?
  final bool cancelled;
  // other field: "AuTag", seems to contain the current day of week as a 1-based index

  const VPTeacherSupervision({required this.beforeSchoolHour, required this.time, required this.timeDesc, required this.location, required this.infoText, required this.cancelled});
  @override
  String toString() {
    return 'VPTeacherSupervision(beforeSchoolHour: $beforeSchoolHour, time: $time, timeDesc: $timeDesc, location: $location, infoText: $infoText, cancelled: $cancelled)';
  }
}

/// Anfrage mit passender Authentifizierung und Kepler-App User Agent
/// no connection => null
Future<http.Response?> authRequest(Uri url, String user, String password) async {
  try {
    return await http.get(url, headers: {
      "Authorization": "Basic ${base64Encode(utf8.encode("$user:$password"))}",
      "User-Agent": "KeplerApp/0.1 (info: $creatorMail)"
    }).timeout(const Duration(seconds: 5));
  } catch (e, s) {
    logCatch("indiware", e, s);
    return null;
  }
}

/// Indiware-Anfrage stellen und verarbeiten
/// returns (data, isOnline)
Future<(XmlDocument?, bool)> _fetch(Uri url, String user, String password) async {
  logDebug("indiware", "fetching ${url.toString()}");
  final res = await authRequest(url, user, password);
  if (res == null) return (null, false);
  if (res.statusCode == 401) throw StateError("authentication failed");
  if (res.statusCode == 404) return (null, true);
  final xml = XmlDocument.parse(utf8.decode(res.bodyBytes));
  return (xml, true);
}

/// Klassen-XML abfragen
/// returns (data, isOnline)
Future<(XmlDocument?, bool)> getKlassenXML(String host, String user, String password) async {
  if (host == indiwareDemoHost) return (null, true);
  final xml = await _fetch(sUrlMKlXmlUrl(host), user, password);
  return xml;
}

/// Lehrer-XML abfragen
/// returns (data, isOnline)
Future<(XmlDocument?, bool)> getLehrerXML(String host, String user, String password) async {
  if (host == indiwareDemoHost) return (null, false);
  final xml = await _fetch(lUrlMLeXmlUrl(host), user, password);
  return xml;
}

/// Datumsformat für Indiware-Plan-XML-Dateien (PlanKlyyyyMMdd.xml bzw. PlanLeyyyyMMdd.xml)
final indiwareFilenameFormat = DateFormat("yyyyMMdd");

/// Schülerplan-XML-Daten für Datum abfragen
/// returns (data, isOnline)
Future<(XmlDocument?, bool)> getKlXMLForDate(String host, String user, String password, DateTime date)
  => _fetch(Uri.parse("$host$sUrlMPath/mobdaten/PlanKl${indiwareFilenameFormat.format(date)}.xml"), user, password);

/// Lehrerplan-XML-Daten für Datum abfragen
/// returns (data, isOnline)
Future<(XmlDocument?, bool)> getLeXMLForDate(String host, String user, String password, DateTime date)
  => _fetch(Uri.parse("$host$lUrlMPath/mobdaten/PlanLe${indiwareFilenameFormat.format(date)}.xml"), user, password);

/// VPHeader aus XML erstellen
VPHeader _parseHeader(XmlElement kopf) => VPHeader(
  lastUpdated: kopf.getElement("zeitstempel")!.innerText,
  dataDate: kopf.getElement("DatumPlan")!.innerText,
  filename: kopf.getElement("datei")!.innerText,
);

/// VPHolidays aus XML erstellen
VPHolidays _parseHolidays(XmlElement freieTage) => VPHolidays(
  holidayDateStrings: freieTage.childElements.map((e) => e.innerText).toList(),
);

/// VPHourBlock-s aus XML erstellen
List<VPHourBlock> _parseHourBlocks(XmlElement klStunden) =>
  klStunden.childElements.map((klSt) => VPHourBlock(
    startTime: HMTime.fromTimeString(klSt.getAttribute("ZeitVon")!),
    endTime: HMTime.fromTimeString(klSt.getAttribute("ZeitBis")!),
    blockStartLesson: int.parse(klSt.innerText),
  )).toList();

/// Hilfsfunktionen für null-Checks
HMTime? _timeOrNull(String? time) => (time == null || time == "") ? null : HMTime.fromTimeString(time);
int? _intOrNull(String? nr) => (nr == null || nr == "") ? null : int.parse(nr);

/// VPLesson-s aus XML erstellen
List<VPLesson> _parseLessons(XmlElement pl) =>
  pl.childElements.map((std) => VPLesson(
    schoolHour: int.parse(std.getElement("St")!.innerText),
    startTime: _timeOrNull(std.getElement("Beginn")?.innerText),
    endTime: _timeOrNull(std.getElement("Ende")?.innerText),
    subjectCode: std.getElement("Fa")!.innerText,
    subjectChanged: std.getElement("Fa")!.getAttribute("FaAe") == "FaGeaendert",
    teacherCode: std.getElement("Le")!.innerText,
    teacherChanged: std.getElement("Le")!.getAttribute("LeAe") == "LeGeaendert",
    roomCodes: (){
      final txt = std.getElement("Ra")!.innerText.trim();
      if (txt == "") return <String>[];
      return txt.split(" ");
    }(),
    roomChanged: std.getElement("Ra")!.getAttribute("RaAe") == "RaGeaendert",
    subjectID: _intOrNull(std.getElement("Nr")?.innerText.replaceAll(RegExp(r'[^0-9]+'), "")),
    infoText: std.getElement("If")?.innerText ?? "",
  )).toList();

/// Infotext aus XML erstellen
List<String> _parseAdditionalInfo(XmlElement? zusatzInfo) =>
  zusatzInfo?.childElements.map((e) => e.innerText).toList() ?? [];

/// komplettes VPKlData-Objekt aus XML erstellen
VPKlData xmlToKlData(XmlDocument klData) {
  final xml = klData.rootElement;
  final classes = xml.getElement("Klassen")!.childElements.toList();
  return VPKlData(
    header: _parseHeader(xml.getElement("Kopf")!),
    holidays: _parseHolidays(xml.getElement("FreieTage")!),
    classes: classes.map((e) => VPClass(
      className: e.getElement("Kurz")!.innerText,
      hourBlocks: _parseHourBlocks(e.getElement("KlStunden")!),
      courses: e.getElement("Kurse")!.childElements.map((e2) => VPClassCourse(
        teacherCode: e2.getAttribute("KLe"),
        courseName: e2.innerText,
      )).toList(),
      subjects: e.getElement("Unterricht")!.childElements
        .map((e) => e.getElement("UeNr")!)
        .map((e2) => VPClassSubject(
          teacherCode: e2.getAttribute("UeLe")!,
          subjectCode: e2.getAttribute("UeFa")!,
          additionalDescr: e2.getAttribute("UeGr"),
          subjectID: int.parse(e2.innerText),
        ),
      ).toList(),
      lessons: _parseLessons(e.getElement("Pl")!),
    )).toList(),
    additionalInfo: _parseAdditionalInfo(xml.getElement("ZusatzInfo") ?? XmlElement(XmlName("nah"))),
  );
}

/// komplettes VPLeData-Objekt aus XML erstellen
VPLeData xmlToLeData(XmlDocument leData) {
  final xml = leData.rootElement;
  final teacher = xml.getElement("Klassen")!.childElements.toList();
  return VPLeData(
    header: _parseHeader(xml.getElement("Kopf")!),
    holidays: _parseHolidays(xml.getElement("FreieTage")!),
    teachers: teacher.map((e) => VPTeacher(
      teacherCode: e.getElement("Kurz")!.innerText,
      hourBlocks: _parseHourBlocks(e.getElement("KlStunden")!),
      lessons: _parseLessons(e.getElement("Pl")!),
      supervisions: e.getElement("Aufsichten")!.childElements.map((e2) => VPTeacherSupervision(
        beforeSchoolHour: int.parse(e2.getElement("AuVorStunde")!.innerText),
        time: HMTime.fromTimeString(e2.getElement("AuUhrzeit")!.innerText),
        timeDesc: e2.getElement("AuZeit")!.innerText,
        location: e2.getElement("AuOrt")!.innerText,
        cancelled: e2.getAttribute("AuAe") == "AuAusfall",
        infoText: e2.getElement("AuInfo")?.innerText,
      )).toList(),
    )).toList(),
    additionalInfo: _parseAdditionalInfo(xml.getElement("ZusatzInfo")),
  );
}

/// Klassen-XML-Daten abfragen
/// returns (data, isOnline)
Future<(VPKlData?, bool)> getKlassenXmlKlData(String host, String username, String password) async {
  if (host == indiwareDemoHost) return (null, false);
  final (xml, online) = await getKlassenXML(host, username, password);
  if (xml == null) return (null, online);
  return (xmlToKlData(xml), online);
}

/// Schülerplan-Daten abfragen
/// - da VPKlData nicht direkt gecached werden kann und diese Funktion nicht auf den Cache zugreift,
///   sollte sie eigentlich nie verwendet werden
/// returns (data, isOnline)
Future<(VPKlData?, bool)> getStuPlanDataForDate(String host, String username, String password, DateTime date) async {
  if (host == indiwareDemoHost) return (null, false);
  final (xml, online) = await getKlXMLForDate(host, username, password, date);
  if (xml == null) return (null, online);
  return (xmlToKlData(xml), online);
}

/// Lehrer-XML-Daten abfragen
/// returns (data, isOnline)
Future<(VPLeData?, bool)> getLehrerXmlLeData(String host, String username, String password) async {
  if (host == indiwareDemoHost) return (null, false);
  final (xml, online) = await getLehrerXML(host, username, password);
  if (xml == null) return (null, online);
  return (xmlToLeData(xml), online);
}

/// Lehrerplan-Daten abfragen
/// - da VPLeData nicht direkt gecached werden kann und diese Funktion nicht auf den Cache zugreift,
///   sollte sie eigentlich nie verwendet werden
/// returns (data, isOnline)
Future<(VPLeData?, bool)> getLehPlanDataForDate(String host, String username, String password, DateTime date) async {
  if (host == indiwareDemoHost) return (null, false);
  final (xml, online) = await getLeXMLForDate(host, username, password, date);
  if (xml == null) return (null, online);
  return (xmlToLeData(xml), online);
}

// --- desktop data fetching ---

/// Root-Element für Schülerdesktopdaten
class VPKLDesktopData {
  /// Element `<kopf>`
  final XmlElement? header;
  /// Element `<freietage>`
  final XmlElement? holidays;
  /// Element `<aufsichten>`
  final XmlElement? teacherWatch;
  /// Element `<fuss>`
  final XmlElement? footer;
  /// Element `<haupt>`
  final XmlElement? mainInfo;
  /// aus Element `<klausuren>`
  final List<VPExam>? exams;

  const VPKLDesktopData({
    required this.header,
    required this.holidays,
    required this.teacherWatch,
    required this.footer,
    required this.mainInfo,
    required this.exams,
  });
}

/// Serializable, damit nur die Klausuren aus dem Desktop-XML gespeichert werden müssen
/// - aus Unterelement `<klausur>` von `<klausuren>`
class VPExam extends SerializableObject {
  /// aus Element `<jahrgang>`
  String get year => attributes["year"];
  set year(String val) => attributes["year"] = val;

  /// aus Element `<kurs>`
  String get subject => attributes["subject"];
  set subject(String val) => attributes["subject"] = val;

  /// aus Element `<kursleiter>`
  String get teacher => attributes["teacher"];
  set teacher(String val) => attributes["teacher"] = val;

  /// aus Element `<stunde>`
  String get hour => attributes["hour"];
  set hour(String val) => attributes["hour"] = val;

  /// aus Element `<beginn>`
  String get begin => attributes["begin"];
  set begin(String val) => attributes["begin"] = val;

  /// Dauer in Minuten (ohne Einheit?), als String (weil nichts garantiert ist) - aus Element `<dauer>`
  String get duration => attributes["duration"];
  set duration(String val) => attributes["duration"] = val;

  /// aus Element `<kinfo>`
  String get info => attributes["info"];
  set info(String val) => attributes["info"] = val;

  VPExam({
    required String year,
    required String subject,
    required String teacher,
    required String hour,
    required String begin,
    required String duration,
    required String info,
  }) {
    this.year = year;
    this.subject = subject;
    this.teacher = teacher;
    this.hour = hour;
    this.begin = begin;
    this.duration = duration;
    this.info = info;
  }

  VPExam.fromData(Map<String, dynamic> data) {
    year = data["year"];
    subject = data["subject"];
    teacher = data["teacher"];
    hour = data["hour"];
    begin = data["begin"];
    duration = data["duration"];
    info = data["info"];
  }
}

/// Schülerplan-Desktop-XML-Daten für Datum abfragen
/// returns (data, isOnline)
Future<(XmlDocument?, bool)> getKlDesktopXMLForDate(String host, String user, String password, DateTime date)
  => _fetch(Uri.parse("$host$sUrlDPath/vdaten/VplanKl${indiwareFilenameFormat.format(date)}.xml"), user, password);

/// komplettes VPKLDesktopData-Objekt aus XML erstellen
VPKLDesktopData xmlToKlDesktopData(XmlDocument doc) {
  final xml = doc.rootElement;
  return VPKLDesktopData(
    header: xml.getElement("kopf"),
    holidays: xml.getElement("freietage"),
    teacherWatch: xml.getElement("aufsichten"),
    footer: xml.getElement("fuss"),
    mainInfo: xml.getElement("haupt"),
    exams: xml.getElement("klausuren")?.childElements.map((el) => VPExam(
      year: el.getElement("jahrgang")?.innerText ?? "",
      subject: el.getElement("kurs")?.innerText ?? "",
      teacher: el.getElement("kursleiter")?.innerText ?? "",
      duration: el.getElement("dauer")?.innerText ?? "",
      begin: el.getElement("beginn")?.innerText ?? "",
      hour: el.getElement("stunde")?.innerText ?? "",
      info: el.getElement("kinfo")?.innerText ?? "",
    )).toList(),
  );
}

/// Schüler-Desktop-XML-Daten für Datum abfragen und nur Klausuren zurückgeben
/// returns (data, isOnline)
Future<(List<VPExam>?, bool)> getExamRawDataForDate(String host, String username, String password, DateTime date) async {
  if (host == indiwareDemoHost) return (null, false);
  final (xml, online) = await getKlDesktopXMLForDate(host, username, password, date);
  if (xml == null) return (null, online);
  return (xmlToKlDesktopData(xml).exams, online);
}
