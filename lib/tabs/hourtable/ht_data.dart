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
    transformers["available_subjects"] = (data) =>
      data is String ? _jsonDataStrToMap(data) : jsonEncode(data);
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

  // for better clarity
  String? get selectedTeacherName => selectedClassName;
  set selectedTeacherName(String? val) => selectedClassName = val;

  List<int> get selectedCourseIDs => attributes["selected_course_ids"] ?? [];
  set selectedCourseIDs(List<int> sc) {
    attributes["selected_course_ids"] = sc;
    notifyListeners();
    save();
  }

  List<String> get availableClasses => attributes["available_classes"] ?? [];
  set availableClasses(List<String> ac) {
    attributes["available_classes"] = ac;
    notifyListeners();
    save();
  }

  Map<String, List<VPCSubjectS>> get availableSubjects => attributes["available_subjects"] ?? {};
  set availableSubjects(Map<String, List<VPCSubjectS>> ac) {
    attributes["available_subjects"] = ac;
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
}

const stuplanpath = "/stuplans";

class IndiwareDataManager {
  static final fnTimeFormat = DateFormat("yyyy-mm-dd");

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

  static Future<VPKlData?> getKlDataForDate(
      DateTime date, String username, String password, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await getCachedKlDataForDate(date);
      if (cached != null) return cached;
    }
    final real = await getKlXMLForDate(username, password, date);
    if (real == null) return null;
    await _setCachedKlDataForDate(date, real);
    return xmlToKlData(real);
  }
  static Future<VPLeData?> getLeDataForDate(
      DateTime date, String username, String password, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await getCachedLeDataForDate(date);
      if (cached != null) return cached;
    }
    final real = await getLeXMLForDate(username, password, date);
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
      if (date.isBefore(thresholdDate)) await file.delete();
    }
  }
}
