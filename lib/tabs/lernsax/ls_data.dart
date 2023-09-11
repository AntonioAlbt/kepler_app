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
  }

  void _setSaveNotify(String key, dynamic data) {
    attributes[key] = data;
    notifyListeners();
    save();
  }

  List<LSNotification> get notifications => (attributes["notifs"] as List<LSNotification>? ?? [])..sort((a, b) => b.date.compareTo(a.date));
  set notifications(List<LSNotification> val) => _setSaveNotify("notifs", val);
  void addNotification(LSNotification notif, {bool sort = true}) {
    final l = notifications;
    if (l.contains(notif)) return;
    l.add(notif);
    if (sort) l.sort((a, b) => a.date.compareTo(b.date));
    notifications = l;
  }

  final _serializer = Serializer();
  bool loaded = false;
  final Lock _fileLock = Lock();
  Future<void> save() async {
    if (_fileLock.locked) log("The file lock for StuPlanData (file: cache/$lernSaxDataPrefsKey-data.json) is still locked!!! This means waiting...");
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
