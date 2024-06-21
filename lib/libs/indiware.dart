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
import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;

const baseUrl = "https://plan.kepler-chemnitz.de/stuplanindiware";
const indiwareDemoHost = "demo";

const sUrlDPath = "/VplanonlineS";
const sUrlMPath = "/VmobilS";
const sUrlMKlXmlPath = "$sUrlMPath/mobdaten/Klassen.xml";

const lUrlDPath = "/VplanonlineL";
const lUrlMPath = "/VmobilL";
const lUrlMLeXmlPath = "$lUrlMPath/mobdaten/Lehrer.xml";

Uri sUrlMKlXmlUrl(String host) => Uri.parse("$host$sUrlMKlXmlPath");
Uri lUrlMLeXmlUrl(String host) => Uri.parse("$host$lUrlMLeXmlPath");

class HMTime extends SerializableObject {
  int get hour => attributes["hour"];
  set hour(int val) => attributes["hour"] = val;

  int get minute => attributes["minute"];
  set minute(int val) => attributes["minute"] = val;

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

class VPKlData {
  final VPHeader header; // "Kopf"
  final VPHolidays holidays; // "FreieTage"
  final List<VPClass> classes; // "Klassen"
  final List<String> additionalInfo; // "ZusatzInfo" -> "ZiZeile" values

  const VPKlData({required this.header, required this.holidays, required this.classes, required this.additionalInfo});
  @override
  String toString() {
    return 'VPKlData(header: $header, holidays: $holidays, classes: $classes, additionalInfo: $additionalInfo)';
  }
}

class VPLeData {
  final VPHeader header; // "Kopf"
  final VPHolidays holidays; // "FreieTage"
  final List<VPTeacher> teachers; // "Klassen"
  final List<String> additionalInfo; // "ZusatzInfo" -> "ZiZeile" values

  const VPLeData({required this.header, required this.holidays, required this.teachers, required this.additionalInfo});
  @override
  String toString() {
    return 'VPLeData(header: $header, holidays: $holidays, teacher: $teachers, additionalInfo: $additionalInfo)';
  }
}

class VPHeader {
  final String lastUpdated; // "zeitstempel"
  final String dataDate; // "DatumPlan"
  final String filename; // "dateiname"
  // other fields: "planart", "nativ", "woche", "tageprowoche", "schulnummer"

  const VPHeader({required this.lastUpdated, required this.dataDate, required this.filename});
  @override
  String toString() {
    return 'VPHeader(lastUpdated: $lastUpdated, dataDate: $dataDate, filename: $filename)';
  }
}

class VPHolidays {
  final List<String> holidayDateStrings;

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
  final String className;
  // other field: "Hash" - seems to always be empty
  final List<VPHourBlock> hourBlocks; // "KlStunden"
  final List<VPClassCourse> courses; // "Kurse"
  final List<VPClassSubject> subjects; // "Unterricht"
  final List<VPLesson> lessons; // "Pl"

  const VPClass({required this.className, required this.hourBlocks, required this.courses, required this.subjects, required this.lessons});
  @override
  String toString() {
    return 'VPClass(className: $className, hourBlocks: $hourBlocks, courses: $courses, subjects: $subjects, lessons: $lessons)';
  }
}

class VPHourBlock { // "KlSt"
  final HMTime startTime; // "ZeitVon"
  final HMTime endTime; // "ZeitBis"
  final int blockStartLesson; // value

  const VPHourBlock({required this.startTime, required this.endTime, required this.blockStartLesson});
  @override
  String toString() {
    return 'VPHourBlock(startTime: $startTime, endTime: $endTime, blockStartLesson: $blockStartLesson)';
  }
}

class VPClassCourse { // "Ku" -> "KKz"
  final String? teacherCode; // "KLe"
  final String courseName; // value

  const VPClassCourse({required this.teacherCode, required this.courseName});
  @override
  String toString() {
    return 'VPClassCourse(teacherCode: $teacherCode, courseName: $courseName)';
  }
}

class VPClassSubject { // "<Ue>" -> "<UeNr>"
  final String teacherCode; // "UeLe"
  final String subjectCode; // "UeFa"
  /// only sometimes defined, seems to include additional info about some subjects (usually the "courses")
  final String? additionalDescr; // "UeGr"
  final int subjectID; // value

  const VPClassSubject({required this.teacherCode, required this.subjectCode, this.additionalDescr, required this.subjectID});
  @override
  String toString() {
    return 'VPClassSubject(teacherCode: $teacherCode, subjectCode: $subjectCode, additionalDescr: $additionalDescr, subjectID: $subjectID)';
  }
}

class VPLesson { // "<Std>"
  final int schoolHour; // "St"
  final HMTime? startTime; // "Beginn"
  final HMTime? endTime; // "Ende"
  final String subjectCode; // "Fa" -> value
  final bool subjectChanged; // "Fa.FaAe == FaGeaendert"
  final String teacherCode; // "Le" -> value
  final bool teacherChanged; // "Le.LeAe == LeGeaendert"
  final List<String> roomCodes; // "Ra" -> value
  final bool roomChanged; // "Ra.RaAe == RaGeaendert"
  final int? subjectID; // "Nr"
  final String infoText; // "If"
  
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
}

const cancellationALaLernSax = "Aufgaben in LernSax bearbeiten";

VPLesson considerLernSaxCancellationForLesson(VPLesson lesson, bool considerIt, {String roomOverride = ""}) {
  if (!considerIt) return lesson;
  if (lesson.subjectChanged || lesson.teacherCode != "") return lesson; // this might mean that the tasks are actually meant to be done in school
  if (!lesson.infoText.contains(cancellationALaLernSax)) return lesson;
  return lesson.copyWith(subjectCode: "---", subjectChanged: true, teacherCode: "", teacherChanged: true, roomCodes: (roomOverride == "") ? [] : [roomOverride], roomChanged: true, infoText: "für ${lesson.subjectCode}${lesson.teacherCode != "" ? " bei ${lesson.teacherCode}" : ""} ${lesson.infoText}");
}

class VPTeacher {
  final String teacherCode;
  // other field: "Hash" - seems to always be empty
  final List<VPHourBlock> hourBlocks; // "KlStunden"
  final List<VPLesson> lessons; // "Pl"
  final List<VPTeacherSupervision> supervisions; // "Aufsichten"

  const VPTeacher({required this.teacherCode, required this.hourBlocks, required this.lessons, required this.supervisions});
  @override
  String toString() {
    return 'VPTeacher(teacherCode: $teacherCode, hourBlocks: $hourBlocks, lessons: $lessons, supervisions: $supervisions)';
  }
}

class VPTeacherSupervision { // "<Aufsicht>"
  final int beforeSchoolHour; // "AuVorStunde"
  final HMTime time; // "AuUhrzeit"
  final String timeDesc; // "AuZeit"
  final String location; // "AuOrt"
  final String? infoText; // "AuInfo"
  final bool cancelled; // "<Aufsicht>.AuAe == AuAusfall"
  // other field: "AuTag", seems to contain the current day of week as a 1-based index

  const VPTeacherSupervision({required this.beforeSchoolHour, required this.time, required this.timeDesc, required this.location, required this.infoText, required this.cancelled});
  @override
  String toString() {
    return 'VPTeacherSupervision(beforeSchoolHour: $beforeSchoolHour, time: $time, timeDesc: $timeDesc, location: $location, infoText: $infoText, cancelled: $cancelled)';
  }
}

/// no connection => null
Future<http.Response?> authRequest(Uri url, String user, String password) async {
  try {
    return await http.get(url, headers: {
      "Authorization": "Basic ${base64Encode(utf8.encode("$user:$password"))}",
      "User-Agent": "KeplerApp/0.1 (info: a.albert@gamer153.dev)"
    }).timeout(const Duration(seconds: 5));
  } catch (e, s) {
    logCatch("indiware", e, s);
    return null;
  }
}

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

/// returns (data, isOnline)
Future<(XmlDocument?, bool)> getKlassenXML(String host, String user, String password) async {
  if (host == indiwareDemoHost) return (null, true);
  final xml = await _fetch(sUrlMKlXmlUrl(host), user, password);
  return xml;
}

/// returns (data, isOnline)
Future<(XmlDocument?, bool)> getLehrerXML(String host, String user, String password) async {
  if (host == indiwareDemoHost) return (null, false);
  final xml = await _fetch(lUrlMLeXmlUrl(host), user, password);
  return xml;
}

final indiwareFilenameFormat = DateFormat("yyyyMMdd");

/// returns (data, isOnline)
Future<(XmlDocument?, bool)> getKlXMLForDate(String host, String user, String password, DateTime date)
  => _fetch(Uri.parse("$host$sUrlMPath/mobdaten/PlanKl${indiwareFilenameFormat.format(date)}.xml"), user, password);

/// returns (data, isOnline)
Future<(XmlDocument?, bool)> getLeXMLForDate(String host, String user, String password, DateTime date)
  => _fetch(Uri.parse("$host$lUrlMPath/mobdaten/PlanLe${indiwareFilenameFormat.format(date)}.xml"), user, password);

VPHeader _parseHeader(XmlElement kopf) => VPHeader(
  lastUpdated: kopf.getElement("zeitstempel")!.innerText,
  dataDate: kopf.getElement("DatumPlan")!.innerText,
  filename: kopf.getElement("datei")!.innerText,
);

VPHolidays _parseHolidays(XmlElement freieTage) => VPHolidays(
  holidayDateStrings: freieTage.childElements.map((e) => e.innerText).toList(),
);

List<VPHourBlock> _parseHourBlocks(XmlElement klStunden) =>
  klStunden.childElements.map((klSt) => VPHourBlock(
    startTime: HMTime.fromTimeString(klSt.getAttribute("ZeitVon")!),
    endTime: HMTime.fromTimeString(klSt.getAttribute("ZeitBis")!),
    blockStartLesson: int.parse(klSt.innerText),
  )).toList();

HMTime? _timeOrNull(String? time) => (time == null || time == "") ? null : HMTime.fromTimeString(time);
int? _intOrNull(String? nr) => (nr == null || nr == "") ? null : int.parse(nr);

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

List<String> _parseAdditionalInfo(XmlElement? zusatzInfo) =>
  zusatzInfo?.childElements.map((e) => e.innerText).toList() ?? [];

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

/// returns (data, isOnline)
Future<(VPKlData?, bool)> getKlassenXmlKlData(String host, String username, String password) async {
  if (host == indiwareDemoHost) return (null, false);
  final (xml, online) = await getKlassenXML(host, username, password);
  if (xml == null) return (null, online);
  return (xmlToKlData(xml), online);
}

/// returns (data, isOnline)
Future<(VPKlData?, bool)> getStuPlanDataForDate(String host, String username, String password, DateTime date) async {
  if (host == indiwareDemoHost) return (null, false);
  final (xml, online) = await getKlXMLForDate(host, username, password, date);
  if (xml == null) return (null, online);
  return (xmlToKlData(xml), online);
}

/// returns (data, isOnline)
Future<(VPLeData?, bool)> getLehrerXmlLeData(String host, String username, String password) async {
  if (host == indiwareDemoHost) return (null, false);
  final (xml, online) = await getLehrerXML(host, username, password);
  if (xml == null) return (null, online);
  return (xmlToLeData(xml), online);
}

/// returns (data, isOnline)
Future<(VPLeData?, bool)> getLehPlanDataForDate(String host, String username, String password, DateTime date) async {
  if (host == indiwareDemoHost) return (null, false);
  final (xml, online) = await getLeXMLForDate(host, username, password, date);
  if (xml == null) return (null, online);
  return (xmlToLeData(xml), online);
}

// --- desktop data fetching ---

class VPKLDesktopData {
  final XmlElement? header;
  final XmlElement? holidays;
  final XmlElement? teacherWatch;
  final XmlElement? footer;
  final XmlElement? mainInfo;
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

class VPExam extends SerializableObject {
  String get year => attributes["year"];
  set year(String val) => attributes["year"] = val;

  String get subject => attributes["subject"];
  set subject(String val) => attributes["subject"] = val;

  String get teacher => attributes["teacher"];
  set teacher(String val) => attributes["teacher"] = val;

  String get hour => attributes["hour"];
  set hour(String val) => attributes["hour"] = val;

  String get begin => attributes["begin"];
  set begin(String val) => attributes["begin"] = val;

  String get duration => attributes["duration"];
  set duration(String val) => attributes["duration"] = val;

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

Future<(XmlDocument?, bool)> getKlDesktopXMLForDate(String host, String user, String password, DateTime date)
  => _fetch(Uri.parse("$host$sUrlDPath/vdaten/VplanKl${indiwareFilenameFormat.format(date)}.xml"), user, password);

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

Future<(List<VPExam>?, bool)> getExamRawDataForDate(String host, String username, String password, DateTime date) async {
  if (host == indiwareDemoHost) return (null, false);
  final (xml, online) = await getKlDesktopXMLForDate(host, username, password, date);
  if (xml == null) return (null, online);
  return (xmlToKlDesktopData(xml).exams, online);
}
