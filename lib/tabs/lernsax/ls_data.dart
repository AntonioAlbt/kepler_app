import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:enough_serialization/enough_serialization.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:synchronized/synchronized.dart';

const lernSaxDataPrefsKey = "lernsaxdata";

Future<String> get lernSaxDataFilePath async => "${await userDataDirPath}/$lernSaxDataPrefsKey-data.json";
class LernSaxData extends SerializableObject with ChangeNotifier {
  LernSaxData() {
    objectCreators["notifs"] = (_) => <LSNotification>[];
    objectCreators["notifs.value"] = (data) => data != null ? LSNotification.data(data) : null;

    objectCreators["tasks"] = (_) => <LSTask>[];
    objectCreators["tasks.value"] = (data) => data != null ? LSTask.data(data) : null;

    objectCreators["memberships"] = (_) => <LSMembership>[];
    objectCreators["memberships.value"] = (data) => data != null ? LSMembership.data(data) : null;
  }

  void _setSaveNotify(String key, dynamic data) {
    attributes[key] = data;
    notifyListeners();
    save();
  }

  List<LSNotification> get notifications => (attributes["notifs"] as List<LSNotification>? ?? [])..sort((a, b) => b.date.compareTo(a.date));
  set notifications(List<LSNotification> val) => _setSaveNotify("notifs", val);
  // void addNotification(LSNotification notif, {bool sort = true}) {
  //   final l = notifications;
  //   if (l.contains(notif)) return;
  //   l.add(notif);
  //   if (sort) l.sort((a, b) => a.date.compareTo(b.date));
  //   notifications = l;
  // }

  List<LSTask> get tasks => (attributes["tasks"] as List<LSTask>? ?? [])..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  set tasks(List<LSTask> val) => _setSaveNotify("tasks", val);
  void addNewTasks(List<LSTask> newTasks, {bool sort = true}) {
    final l = tasks;
    final ids = l.map((e) => e.id);
    l.addAll(newTasks.where((e) => !ids.contains(e.id)));
    if (sort) l.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    tasks = l;
  }

  List<LSMembership>? get memberships => attributes["memberships"];
  set memberships(List<LSMembership>? val) => _setSaveNotify("memberships", val);

  final _serializer = Serializer();
  bool loaded = false;
  final Lock _fileLock = Lock();
  Future<void> save() async {
    if (_fileLock.locked) log("The file lock for LernSaxData (file: cache/$lernSaxDataPrefsKey-data.json) is still locked!!! This means waiting...");
    _fileLock.synchronized(() async => await writeFile(await lernSaxDataFilePath, _serialize()));
  }
  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    try {
      _serializer.deserialize(json, this);
    } catch (e, s) {
      log("Error while decoding json for LernSaxData from file:", error: e, stackTrace: s);
      Sentry.captureException(e, stackTrace: s);
      return;
    }
    loaded = true;
  }
}

class LSNotification extends SerializableObject {
  String get id => attributes["id"];
  set id(String val) => attributes["id"] = val;

  DateTime get date => DateTime.parse(attributes["date"]);
  set date(DateTime val) => attributes["date"] = val.toIso8601String();

  String get messageTypeId => attributes["messageTypeId"];
  set messageTypeId(String val) => attributes["messageTypeId"] = val;

  String get message => attributes["message"];
  set message(String val) => attributes["message"] = val;

  String? get data => attributes["data"];
  set data(String? val) => attributes["data"] = val;

  String? get fromUserLogin => attributes["fromUserLogin"];
  set fromUserLogin(String? val) => attributes["fromUserLogin"] = val; // may be empty

  String? get fromUserName => attributes["fromUserName"];
  set fromUserName(String? val) => attributes["fromUserName"] = val; // may be empty

  String? get fromGroupLogin => attributes["fromGroupLogin"];
  set fromGroupLogin(String? val) => attributes["fromGroupLogin"] = val; // may be empty

  String? get fromGroupName => attributes["fromGroupName"];
  set fromGroupName(String? val) => attributes["fromGroupName"] = val; // may be empty

  bool get unread => attributes["unread"];
  set unread(bool val) => attributes["unread"] = val;

  String? get object => attributes["object"];
  set object(String? val) => attributes["object"] = val;

  LSNotification({
    required String id,
    required DateTime date,
    required String messageTypeId,
    required String message,
    String? data,
    required String fromUserLogin, required String fromUserName,
    required String fromGroupLogin, required String fromGroupName,
    required bool unread,
    String? object,
  }) {
    this.id = id;
    this.date = date;
    this.messageTypeId = messageTypeId;
    this.message = message;
    this.data = data;
    this.fromUserLogin = fromUserLogin == "" ? null : fromUserLogin;
    this.fromUserName = fromUserName == "" ? null : fromUserName;
    this.fromGroupLogin = fromGroupLogin == "" ? null : fromGroupLogin;
    this.fromGroupName = fromGroupName == "" ? null : fromGroupName;
    this.unread = unread;
    this.object = object;
  }

  LSNotification.data(Map<String, dynamic> data) {
    Serializer().deserialize(jsonEncode(data), this);
  }
  
  bool get hasUserData => fromUserName != null || fromUserLogin != null;
  bool get hasGroupName => fromGroupName != null;

  @override
  String toString() {
    return 'LSNotification('
        'id: $id, '
        'date: $date, '
        'messageTypeId: $messageTypeId, '
        'message: $message, '
        'data: $data, '
        'fromUserLogin: $fromUserLogin, '
        'fromUserName: $fromUserName, '
        'fromGroupLogin: $fromGroupLogin, '
        'fromGroupName: $fromGroupName, '
        'unread: $unread, '
        'object: $object'
        ')';
  }
}

class LSTask extends SerializableObject {
  String get id => attributes["id"];
  set id(String val) => attributes["id"] = val;

  // containsKey will always be true if ... != null is true, but the code is more readable this way imo
  // (and the performance also doesn't matter)
  DateTime? get startDate => (attributes.containsKey("start_date") && attributes["start_date"] != null) ? DateTime.parse(attributes["start_date"]) : null;
  set startDate(DateTime? val) => attributes["start_date"] = val?.toIso8601String();

  DateTime? get dueDate => (attributes.containsKey("due_date") && attributes["due_date"] != null) ? DateTime.parse(attributes["due_date"]) : null;
  set dueDate(DateTime? val) => attributes["due_date"] = val?.toIso8601String();

  String? get classLogin => attributes["class_login"];
  set classLogin(String? val) => attributes["class_login"] = val;

  String get title => attributes["title"];
  set title(String val) => attributes["title"] = val;

  String get description => attributes["description"];
  set description(String val) => attributes["description"] = val;

  bool get completed => attributes["completed"];
  set completed(bool val) => attributes["completed"] = val;

  String get createdByLogin => attributes["created_login"];
  set createdByLogin(String val) => attributes["created_login"] = val;

  String get createdByName => attributes["created_name"];
  set createdByName(String val) => attributes["created_name"] = val;

  DateTime get createdAt => DateTime.parse(attributes["created_at"]);
  set createdAt(DateTime val) => attributes["created_at"] = val.toIso8601String();

  LSTask({
    required String id,
    required DateTime? startDate,
    required DateTime? dueDate,
    required String? classLogin,
    required String title,
    required String description,
    required bool completed,
    required String createdByLogin,
    required String createdByName,
    required DateTime createdAt,
  }) {
    this.id = id;
    this.startDate = startDate;
    this.dueDate = dueDate;
    this.classLogin = classLogin;
    this.title = title;
    this.description = description;
    this.completed = completed;
    this.createdByLogin = createdByLogin;
    this.createdByName = createdByName;
    this.createdAt = createdAt;
  }

  LSTask.data(Map<String, dynamic> data) {
    Serializer().deserialize(jsonEncode(data), this);
  }

  @override
  String toString() {
    return 'LSTask('
        'id: $id, '
        'startDate: $startDate, '
        'dueDate: $dueDate, '
        'classLogin: $classLogin, '
        'title: $title, '
        'description: $description, '
        'completed: $completed'
        ')';
  }
}

enum MembershipType {
  institution, group, class_, unknown;
  static MembershipType fromInt(int val) {
    switch (val) {
      case 16: return MembershipType.institution;
      case 18: return MembershipType.group;
      case 19: return MembershipType.class_;
      default: return MembershipType.unknown;
    }
  }
  int toInt() => {
    MembershipType.institution: 16,
    MembershipType.group: 18,
    MembershipType.class_: 19,
    MembershipType.unknown: -1,
  }[this]!;
}

class LSMembership extends SerializableObject {
  String get login => attributes["login"];
  set login(String val) => attributes["login"] = val;

  // from the api json response value with key "name_hr", which could actually mean name - human readable
  // (see here: https://chat.openai.com/share/0191513f-d6ae-466f-acdc-df70e0b2c0bf)
  String get name => attributes["name"];
  set name(String val) => attributes["name"] = val;

  MembershipType get type => MembershipType.fromInt(attributes["type"]);
  set type(MembershipType val) => attributes["type"] = val.toInt();

  List<String> get baseRights => attributes["base_rights"];
  set baseRights(List<String> val) => attributes["base_rights"] = val;

  List<String> get memberRights => attributes["member_rights"];
  set memberRights(List<String> val) => attributes["member_rights"] = val;

  List<String> get effectiveRights => attributes["effective_rights"];
  set effectiveRights(List<String> val) => attributes["effective_rights"] = val;

  LSMembership({
    required String login,
    required String name,
    required List<String> baseRights,
    required List<String> memberRights,
    required List<String> effectiveRights,
  }) {
    this.login = login;
    this.name = name;
    this.baseRights = baseRights;
    this.memberRights = memberRights;
    this.effectiveRights = effectiveRights;

    _setup();
  }

  LSMembership.data(Map<String, dynamic> data) {
    _setup();

    Serializer().deserialize(jsonEncode(data), this);
  }

  void _setup() {
    objectCreators["base_rights"] = (_) => <String>[];
    objectCreators["member_rights"] = (_) => <String>[];
    objectCreators["effective_rights"] = (_) => <String>[];
  }

  @override
  String toString() {
    return 'LSMembership {'
        '\n  login: $login,'
        '\n  name: $name,'
        '\n  baseRights: $baseRights,'
        '\n  memberRights: $memberRights,'
        '\n  effectiveRights: $effectiveRights'
        '\n}';
  }
}
