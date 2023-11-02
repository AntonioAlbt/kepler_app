import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/main.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:synchronized/synchronized.dart';
import 'package:xml/xml.dart';

const stuPlanDataPrefsKey = "stuplandata";

Future<String> get stuPlanDataFilePath async => "${await userDataDirPath}/$stuPlanDataPrefsKey-data.json";
// TODO - future: automatically determine summer holiday end and ask user if their class changed -> maybe with https://ferien-api.de/api/v1/holidays/SN ?
class StuPlanData extends SerializableObject with ChangeNotifier {
  StuPlanData() {
    objectCreators["selected_courses"] = (_) => <String>[];
    objectCreators["available_classes"] = (_) => <String>[];
    objectCreators["selected_course_ids"] = (_) => <int>[];

    objectCreators["available_teachers"] = (_) => <String>[];
  }

  Map<String, List<VPCSubjectS>> _jsonDataStrToMap(String json) {
    if (json == "") return {};
    final mapData = jsonDecode(json) as Map<String, dynamic>;
    final map = <String, List<VPCSubjectS>>{};
    for (final className in mapData.keys) {
      map[className] = <VPCSubjectS>[];
      for (final courseJSON in (mapData[className]! as List<dynamic>)) {
        map[className]!.add(VPCSubjectS(VPClassSubject(
          subjectCode: courseJSON["subject_code"],
          subjectID: courseJSON["subject_id"],
          teacherCode: courseJSON["teacher_code"],
          additionalDescr: courseJSON["add_desc"],
        )));
      }
    }
    return map;
  }

  void _setSaveNotify(String key, dynamic data) {
    attributes[key] = data;
    notifyListeners();
    save();
  }

  DateTime _getUpdateDateTime(String key) {
    if (attributes.containsKey("lu_$key")) {
      return DateTime.tryParse(attributes["lu_$key"]) ?? DateTime(1900);
    } else {
      return DateTime(1900);
    }
  }
  void _setUpdateDateTime(String key, DateTime date) => _setSaveNotify("lu_$key", date.toIso8601String());

  String? get selectedClassName => attributes["selected_class_name"];
  set selectedClassName(String? cn) => _setSaveNotify("selected_class_name", cn);

  List<int> get selectedCourseIDs => attributes["selected_course_ids"] ?? [];
  set selectedCourseIDs(List<int> sc) => _setSaveNotify("selected_course_ids", sc);
  void addSelectedCourse(int id) {
    final l = selectedCourseIDs;
    if (l.contains(id)) return;
    l.add(id);
    selectedCourseIDs = l;
  }
  void removeSelectedCourse(int id) {
    final l = selectedCourseIDs;
    l.remove(id);
    selectedCourseIDs = l;
  }

  DateTime get lastAvailClassesUpdate => _getUpdateDateTime("available_classes");
  set lastAvailClassesUpdate(DateTime val) => _setUpdateDateTime("available_classes", val);
  List<String>? get availableClasses => attributes.containsKey("available_classes") ? attributes["available_classes"] : null;
  set availableClasses(List<String>? ac) => _setSaveNotify("available_classes", ac);

  DateTime get lastAvailSubjectsUpdate => _getUpdateDateTime("available_subjects");
  set lastAvailSubjectsUpdate(DateTime val) => _setUpdateDateTime("available_subjects", val);
  Map<String, List<VPCSubjectS>> get availableSubjects => _jsonDataStrToMap(attributes["available_subjects"] ?? "");
  set availableSubjects(Map<String, List<VPCSubjectS>> ac) => _setSaveNotify("available_subjects", jsonEncode(ac));
  List<VPCSubjectS>? get availableClassSubjects =>
    ((selectedClassName == null) ? null : availableSubjects[selectedClassName])
      ?.where((e) => e.teacherCode != "").toList();
  
  String? get selectedTeacherName => attributes["selected_teacher_name"];
  set selectedTeacherName(String? tn) => _setSaveNotify("selected_teacher_name", tn);

  DateTime get lastAvailTeachersUpdate => _getUpdateDateTime("available_teachers");
  set lastAvailTeachersUpdate(DateTime val) => _setUpdateDateTime("available_teachers", val);
  List<String>? get availableTeachers => attributes.containsKey("available_teachers") ? attributes["available_teachers"] : null;
  set availableTeachers(List<String>? at) => _setSaveNotify("available_teachers", at);

  DateTime get lastHolidayDatesUpdate => _getUpdateDateTime("school_holiday_dates");
  set lastHolidayDatesUpdate(DateTime val) => _setUpdateDateTime("school_holiday_dates", val);
  List<DateTime> get holidayDates => attributes.containsKey("school_holiday_dates") ? (attributes["school_holiday_dates"] as String).split("|").map((str) => DateTime.parse(str)).toList() : [];
  set holidayDates(List<DateTime> val) => _setSaveNotify("school_holiday_dates", val.map((d) => d.toIso8601String()).join("|"));
  void removeHolidayDate(DateTime date) {
    holidayDates = holidayDates.where((d) => !(d.day == date.day && d.month == date.month && d.year == date.year)).toList();
  }
  bool checkIfHoliday(DateTime date) => holidayDates.any((d) => d.day == date.day && d.month == date.month && d.year == date.year);

  final _serializer = Serializer();
  bool loaded = false;
  final Lock _fileLock = Lock();
  Future<void> save() async {
    if (_fileLock.locked) log("The file lock for StuPlanData (file: cache/$stuPlanDataPrefsKey-data.json) is still locked!!! This means waiting...");
    _fileLock.synchronized(() async => await writeFile(await stuPlanDataFilePath, _serialize()));
  }
  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    try {
      _serializer.deserialize(json, this);
    } catch (e, s) {
      log("Error while decoding json for StuPlanData from file:", error: e, stackTrace: s);
      if (globalSentryEnabled) Sentry.captureException(e, stackTrace: s);
      return;
    }
    loaded = true;
  }

  void loadDataFromKlData(VPKlData data) {
    availableClasses = data.classes.map((e) => e.className).toList();
    lastAvailClassesUpdate = DateTime.now();
    availableSubjects = data.classes.fold({}, (val, element) {
      val[element.className] = element.subjects.map((c) => VPCSubjectS(c)).toList();
      return val;
    });
    lastAvailSubjectsUpdate = DateTime.now();
  }

  void loadDataFromLeData(VPLeData data) {
    availableTeachers = data.teachers.map((e) => e.teacherCode).toList();
    lastAvailTeachersUpdate = DateTime.now();
  }
}

/// VPClassSubject, but serializable
class VPCSubjectS extends SerializableObject {
  String get teacherCode => attributes["teacher_code"];
  String get subjectCode => attributes["subject_code"];
  String? get additionalDescr => attributes["add_desc"];
  int get subjectID => attributes["subject_id"];

  VPCSubjectS(VPClassSubject subject) {
    attributes["teacher_code"] = subject.teacherCode;
    attributes["subject_code"] = subject.subjectCode;
    attributes["add_desc"] = subject.additionalDescr;
    attributes["subject_id"] = subject.subjectID;
  }
  VPCSubjectS.empty();

  Map<String, dynamic> toJson() => {
    "teacher_code": teacherCode,
    "subject_code": subjectCode,
    "add_desc": additionalDescr,
    "subject_id": subjectID,
  };
}

const stuplanpath = "/stuplans";

class IndiwareDataManager {
  static final fnTimeFormat = DateFormat("yyyy-MM-dd");

  static Future<VPKlData?> getCachedKlDataForDate(DateTime date) async {
    final xml = await readFile("${await appDataDirPath}$stuplanpath/${fnTimeFormat.format(date)}-kl.xml");
    if (xml == null) return null;
    return xmlToKlData(XmlDocument.parse(xml));
  }
  static Future<VPLeData?> getCachedLeDataForDate(DateTime date) async {
    final xml = await readFile("${await appDataDirPath}$stuplanpath/${fnTimeFormat.format(date)}-le.xml");
    if (xml == null) return null;
    return xmlToLeData(XmlDocument.parse(xml));
  }
  static Future<VPKlData?> getCachedKlassenXmlData() async {
    final f = File("${await appDataDirPath}$stuplanpath/Klassen-kl.xml");
    // force-refresh Klassen.xml every 30 days
    if ((await f.lastModified()).difference(DateTime.now()).inDays > 30) {
      await f.delete();
      return null;
    }
    final xml = await readFile(f.path);
    if (xml == null) return null;
    return xmlToKlData(XmlDocument.parse(xml));
  }

  static Future<void> setCachedKlDataForDate(DateTime date, XmlDocument data) async {
    await writeFile("${await appDataDirPath}$stuplanpath/${fnTimeFormat.format(date)}-kl.xml", data.toXmlString());
  }
  static Future<void> setCachedLeDataForDate(DateTime date, XmlDocument data) async {
    await writeFile("${await appDataDirPath}$stuplanpath/${fnTimeFormat.format(date)}-le.xml", data.toXmlString());
  }
  static Future<void> setKlassenXmlData(XmlDocument data) async {
    await writeFile("${await appDataDirPath}$stuplanpath/Klassen-kl.xml", data.toXmlString());
  }

  static Future<void> clearCachedData({ DateTime? excludeDate }) async {
    final dir = Directory("${await appDataDirPath}$stuplanpath");
    for (var file in (await dir.list().toList())) {
      final name = file.path.split("/").last;
      if (name.endsWith(".xml")) {
        // this will fail when we're in year 21xx
        // but that's a problem for future robot me
        // - actually, it won't be (anymore?). why did i write this???
        if (excludeDate != null && !name.contains(fnTimeFormat.format(excludeDate))) await file.delete();
      }
    }
  }

  /// returns (data, isOnline)
  static Future<(VPKlData?, bool)> getKlDataForDate(
      DateTime date, String host, String username, String password, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await getCachedKlDataForDate(date);
      if (cached != null) return (cached, false);
    }
    final (real, online) = await getKlXMLForDate(host, username, password, date);
    if (real == null) return (null, online);
    await setCachedKlDataForDate(date, real);
    return (xmlToKlData(real), online);
  }
  /// returns (data, isOnline)
  static Future<(VPLeData?, bool)> getLeDataForDate(
      DateTime date, String host, String username, String password, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await getCachedLeDataForDate(date);
      if (cached != null) return (cached, false);
    }
    final (real, online) = await getLeXMLForDate(host, username, password, date);
    if (real == null) return (null, online);
    await setCachedLeDataForDate(date, real);
    return (xmlToLeData(real), online);
  }
  /// returns (data, isOnline)
  static Future<(VPKlData?, bool)> getKlassenXmlData(
      String host, String username, String password, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await getCachedKlassenXmlData();
      if (cached != null) return (cached, false);
    }
    final (real, online) = await getKlassenXML(host, username, password);
    if (real == null) return (null, online);
    await setKlassenXmlData(real);
    return (xmlToKlData(real), online);
  }

  // now following: setup methods

  static Future<void> createDataDirIfNecessary() async {
    final dir = Directory("${await appDataDirPath}$stuplanpath");
    if (await dir.exists()) return;
    await dir.create(recursive: true);
  }

  static Future<void> removeOldCacheFiles() async {
    final dir = Directory("${await appDataDirPath}$stuplanpath");
    final thresholdDate = DateTime.now().subtract(const Duration(days: 3));
    for (final file in (await dir.list().toList())) {
      final fnDateStr = file.path.split("/").last.replaceAll(RegExp(r"-le|-kl|\.xml"), "");
      if (fnDateStr == "Klassen") continue;
      final date = fnTimeFormat.parse(fnDateStr);
      if (kDebugMode) print("found stuplan data xml with date ${fnTimeFormat.format(date)}, will be deleted: ${date.isBefore(thresholdDate)} - threshold: ${fnTimeFormat.format(thresholdDate)}");
      if (date.isBefore(thresholdDate)) await file.delete();
    }
  }
}
