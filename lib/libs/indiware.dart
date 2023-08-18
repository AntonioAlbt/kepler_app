import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;

const baseUrl = "https://plan.kepler-chemnitz.de/stuplanindiware";
const sUrlD = "$baseUrl/VplanonlineS";
const sUrlM = "$baseUrl/VmobilS";
const lUrlD = "$baseUrl/VplanonlineL";
const lUrlM = "$baseUrl/VmobilL";

final sUrlMKlXmlUrl = Uri.parse("$sUrlM/mobdaten/Klassen.xml");
final lUrlMLeXmlUrl = Uri.parse("$lUrlM/mobdaten/Lehrer.xml");

class HMTime {
  final int hour;
  final int minute;

  DateTime toDateTime(DateTime? dayBase) => DateTime(0, 1, 1, hour, minute);

  const HMTime(this.hour, this.minute);

  HMTime.fromStrings(String hour, String minute) :
    hour = int.parse(hour),
    minute = int.parse(minute);
  
  HMTime.fromTimeString(String timeString)
      : hour = int.parse(timeString.split(':')[0]),
        minute = int.parse(timeString.split(':')[1]);
  
  @override
  String toString() {
    return '$hour:$minute';
  }
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
  final List<VPTeacher> teacher; // "Klassen"
  final List<String> additionalInfo; // "ZusatzInfo" -> "ZiZeile" values

  const VPLeData({required this.header, required this.holidays, required this.teacher, required this.additionalInfo});
  @override
  String toString() {
    return 'VPLeData(header: $header, holidays: $holidays, teacher: $teacher, additionalInfo: $additionalInfo)';
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
  final String roomNr; // "Ra" -> value
  final bool roomChanged; // "Ra.RaAe == RaGeaendert"
  final int? subjectID; // "Nr"
  final String infoText; // "If"
  
  // additional access method for better clarity in the code
  String get teachingClassName => teacherCode;
  bool get teachingClassChanged => teacherChanged;

  const VPLesson({required this.schoolHour, required this.startTime, required this.endTime, required this.subjectCode, required this.subjectChanged, required this.teacherCode, required this.teacherChanged, required this.roomNr, required this.roomChanged, required this.subjectID, required this.infoText});
  @override
  String toString() {
    return 'VPLesson(schoolHour: $schoolHour, startTime: $startTime, endTime: $endTime, subjectCode: $subjectCode, subjectChanged: $subjectChanged, teacherCode: $teacherCode, teacherChanged: $teacherChanged, roomNr: $roomNr, roomChanged: $roomChanged, subjectID: $subjectID, infoText: $infoText)';
  }
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

Future<http.Response> authRequest(Uri url, String user, String password) async
  => http.get(url, headers: {
    "Authorization": "Basic ${base64Encode(utf8.encode("$user:$password"))}",
    "User-Agent": "KeplerApp/0.1 (info: a.albert@gamer153.dev)"
  });

Future<XmlDocument?> _fetch(Uri url, String user, String password) async {
  final res = await authRequest(url, user, password);
  if (res.statusCode == 401) throw StateError("authentication failed");
  if (res.statusCode == 404) return null;
  final xml = XmlDocument.parse(utf8.decode(res.bodyBytes));
  return xml;
}

Future<XmlDocument> _getKlassenXML(String user, String password) async {
  final xml = await _fetch(sUrlMKlXmlUrl, user, password);
  return xml!;
}

Future<XmlDocument> _getLehrerXML(String user, String password) async {
  final xml = await _fetch(lUrlMLeXmlUrl, user, password);
  return xml!;
}

final indiwareFilenameFormat = DateFormat("yyyyMMdd");

Future<XmlDocument?> getKlXMLForDate(String user, String password, DateTime date)
  => _fetch(Uri.parse("$sUrlM/mobdaten/PlanKl${indiwareFilenameFormat.format(date)}.xml"), user, password);

Future<XmlDocument?> getLeXMLForDate(String user, String password, DateTime date)
  => _fetch(Uri.parse("$lUrlM/mobdaten/PlanLe${indiwareFilenameFormat.format(date)}.xml"), user, password);

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
    roomNr: std.getElement("Ra")!.innerText,
    roomChanged: std.getElement("Ra")!.getAttribute("RaAe") == "RaGeaendert",
    subjectID: _intOrNull(std.getElement("Nr")?.innerText),
    infoText: std.getElement("If")?.innerText ?? "",
  )).toList();

List<String> _parseAdditionalInfo(XmlElement zusatzInfo) =>
  zusatzInfo.childElements.map((e) => e.innerText).toList();

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
    teacher: teacher.map((e) => VPTeacher(
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
    additionalInfo: _parseAdditionalInfo(xml.getElement("ZusatzInfo")!),
  );
}

// multiple elements in the code above were inspired by or copied from ChatGPT: https://chat.openai.com/share/fbf40d1c-5c5f-4b9f-98fd-bf73e7273f6f

Future<VPKlData> getKlassenXml(String username, String password) async =>
  xmlToKlData(await _getKlassenXML(username, password));

Future<VPKlData?> getStuPlanDataForDate(String username, String password, DateTime date) async {
  final xml = await getKlXMLForDate(username, password, date);
  if (xml == null) return null;
  return xmlToKlData(xml);
}

Future<VPLeData> getLehrerXml(String username, String password) async =>
  xmlToLeData(await _getLehrerXML(username, password));

Future<VPLeData?> getLehPlanDataForDate(String username, String password, DateTime date) async {
  final xml = await getLeXMLForDate(username, password, date);
  if (xml == null) return null;
  return xmlToLeData(xml);
}
