import 'dart:convert';
import 'dart:io';

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:xml/xml.dart';

const stuPlanDataPrefsKey = "stuplandata";

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

  String? get selectedClassName => attributes["selected_class_name"];
  set selectedClassName(String? cn) {
    attributes["selected_class_name"] = cn;
    notifyListeners();
    save();
  }

  List<int> get selectedCourseIDs => attributes["selected_course_ids"] ?? [];
  set selectedCourseIDs(List<int> sc) {
    attributes["selected_course_ids"] = sc;
    notifyListeners();
    save();
  }
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

  List<String> get availableClasses => attributes["available_classes"] ?? [];
  set availableClasses(List<String> ac) {
    attributes["available_classes"] = ac;
    notifyListeners();
    save();
  }

  Map<String, List<VPCSubjectS>> get availableSubjects => _jsonDataStrToMap(attributes["available_subjects"] ?? "");
  set availableSubjects(Map<String, List<VPCSubjectS>> ac) {
    attributes["available_subjects"] = jsonEncode(ac);
    notifyListeners();
    save();
  }
  List<VPCSubjectS>? get availableClassSubjects =>
    ((selectedClassName == null) ? null : availableSubjects[selectedClassName])
      ?.where((e) => e.teacherCode != "").toList();
  
  String? get selectedTeacherName => attributes["selected_teacher_name"];
  set selectedTeacherName(String? tn) {
    attributes["selected_teacher_name"] = tn;
    notifyListeners();
    save();
  }
  List<String> get availableTeachers => attributes["available_teachers"] ?? [];
  set availableTeachers(List<String> at) {
    attributes["available_teachers"] = at;
    notifyListeners();
    save();
  }

  final _serializer = Serializer();
  bool loaded = false;
  save() async {
    sharedPreferences.setString(stuPlanDataPrefsKey, _serialize());
  }
  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    // _serializer.deserialize("{}", this);
    // save();
    _serializer.deserialize(json, this);
    loaded = true;
  }

  void loadDataFromKlData(VPKlData data) {
    availableClasses = data.classes.map((e) => e.className).toList();
    availableSubjects = data.classes.fold({}, (val, element) {
      val[element.className] = element.subjects.map((c) => VPCSubjectS(c)).toList();
      return val;
    });
  }

  void loadDataFromLeData(VPLeData data) {
    availableTeachers = data.teachers.map((e) => e.teacherCode).toList();
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

// bool wrapper for pass-by-reference
class Bw {
  bool? val;
  Bw(this.val);
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

  static Future<void> _setCachedKlDataForDate(DateTime date, XmlDocument data) async {
    await writeFile("${await appDataDirPath}$stuplanpath/${fnTimeFormat.format(date)}-kl.xml", data.toXmlString());
  }
  static Future<void> _setCachedLeDataForDate(DateTime date, XmlDocument data) async {
    await writeFile("${await appDataDirPath}$stuplanpath/${fnTimeFormat.format(date)}-le.xml", data.toXmlString());
  }

  static Future<void> clearCachedData() async {
    final dir = Directory("${await appDataDirPath}$stuplanpath");
    for (var file in (await dir.list().toList())) {
      final name = file.path.split("/").last;
      if (name.endsWith(".xml") && name.startsWith("20")) {
        // this will fail when we're in year 21xx
        // but that's a problem for future robot me
        await file.delete();
      }
    }
  }

  static Future<VPKlData?> getKlDataForDate(
      DateTime date, String username, String password, {bool forceRefresh = false, Bw? fromCache}) async {
    if (!forceRefresh) {
      final cached = await getCachedKlDataForDate(date);
      fromCache?.val = true;
      if (cached != null) return cached;
    }
    final real = await getKlXMLForDate(username, password, date);
    fromCache?.val = false;
    if (real == null) return null;
    await _setCachedKlDataForDate(date, real);
    return xmlToKlData(real);
  }
  static Future<VPLeData?> getLeDataForDate(
      DateTime date, String username, String password, {bool forceRefresh = false, Bw? fromCache}) async {
    if (!forceRefresh) {
      final cached = await getCachedLeDataForDate(date);
      fromCache?.val = true;
      if (cached != null) return cached;
    }
    final real = await getLeXMLForDate(username, password, date);
    fromCache?.val = false;
    if (real == null) return null;
    await _setCachedLeDataForDate(date, real);
    return xmlToLeData(real);
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
      final fn = file.path.split("/").last.replaceAll(RegExp(r"-le|-kl|\.xml"), "");
      final date = fnTimeFormat.parse(fn);
      if (kDebugMode) print("found stuplan data xml with date ${fnTimeFormat.format(date)}, will be deleted: ${date.isBefore(thresholdDate)} - threshold: ${fnTimeFormat.format(thresholdDate)}");
      if (date.isBefore(thresholdDate)) await file.delete();
    }
  }
}
