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
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:enough_serialization/enough_serialization.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:synchronized/synchronized.dart';


/// Die meisten Klassen hier repräsentieren die Daten, die von der API zurückgegeben werden.
/// Die offizielle Dokumentation hilft zwar kaum, weil sie nie auf die Rückgabewerte eingeht, aber hier ist
/// trotzdem ein Link: https://www.lernsax.de/wws/api.php
/// 
/// Teilweise werden unwichtige oder unverständliche Felder ausgelassen. Teilweise sind die Klassen selbst wieder
/// in JSON umwandelbar (dann, wenn sie offline gecached werden sollen).
/// 
/// Die eigentlichen API-Anfragen, die diese Klassen hier zurückgeben, finden sich in libs/lernsax.dart.
/// (Das ist irgendwie seltsam aufgeteilt, und ich weiß auch nicht mehr, warum ich das so gemacht habe.)


/// Speicherschlüssel für die LS-Daten in den SharedPrefs
const lernSaxDataPrefsKey = "lernsaxdata";

/// da durch das Cachen von Mails der Cache relativ groß werden könnte, werden die Daten stattdessen in eine
/// Datei im privaten App-Speicher geschrieben
Future<String> get lernSaxDataFilePath async => "${await userDataDirPath}/$lernSaxDataPrefsKey-data.json";

/// Provider für LernSax-Daten, die gecached werden sollen
/// 
/// Einige Datenfelder haben den Zeitpunkt des letzten Updates mit definiert, damit der Benutzer darauf hingewiesen
/// werden kann, wenn die Daten lange nicht mehr aktualisiert wurden.
/// 
/// Da es für alle Daten nur einen Cache gibt, werden nur die Daten für den primären Benutzer gecached. Alle anderen
/// Benutzer können nur verwendet werden, wenn man online ist.
class LernSaxData extends SerializableObject with ChangeNotifier {
  LernSaxData() {
    objectCreators["notifs"] = (_) => <LSNotification>[];
    objectCreators["notifs.value"] = (data) => data != null ? LSNotification.data(data) : null;

    objectCreators["tasks"] = (_) => <LSTask>[];
    objectCreators["tasks.value"] = (data) => data != null ? LSTask.data(data) : null;

    objectCreators["memberships"] = (_) => <LSMembership>[];
    objectCreators["memberships.value"] = (data) => data != null ? LSMembership.data(data) : null;

    objectCreators["mail_folders"] = (_) => <LSMailFolder>[];
    objectCreators["mail_folders.value"] = (data) => data != null ? LSMailFolder.data(data) : null;
    objectCreators["mail_listings"] = (_) => <LSMailListing>[];
    objectCreators["mail_listings.value"] = (data) => data != null ? LSMailListing.data(data) : null;
    objectCreators["mails"] = (_) => <LSMail>[];
    objectCreators["mails.value"] = (data) => data != null ? LSMail.data(data) : null;
  }

  void _setSaveNotify(String key, dynamic data) {
    attributes[key] = data;
    notifyListeners();
    save();
  }

  DateTime get lastNotificationsUpdate => (attributes.containsKey("lu_notifs") && attributes["lu_notifs"] != null) ? DateTime.parse(attributes["lu_notifs"]) : DateTime(1900);
  set lastNotificationsUpdate(DateTime val) => attributes["lu_notifs"] = val.toIso8601String();
  Duration get lastNotificationsUpdateDiff => lastNotificationsUpdate.difference(DateTime.now()).abs();
  List<LSNotification>? get notifications => (attributes["notifs"] as List<LSNotification>? ?? [])..sort((a, b) => b.date.compareTo(a.date));
  set notifications(List<LSNotification>? val) => _setSaveNotify("notifs", val);

  DateTime get lastTasksUpdate => (attributes.containsKey("lu_tasks") && attributes["lu_tasks"] != null) ? DateTime.parse(attributes["lu_tasks"]) : DateTime(1900);
  set lastTasksUpdate(DateTime val) => attributes["lu_tasks"] = val.toIso8601String();
  Duration get lastTasksUpdateDiff => lastTasksUpdate.difference(DateTime.now()).abs();
  List<LSTask>? get tasks => (attributes["tasks"] as List<LSTask>? ?? [])..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  set tasks(List<LSTask>? val) => _setSaveNotify("tasks", val);
  /// alle neuen Tasks aus `newTasks` zu `tasks` hinzufügen
  void addTasksNew(List<LSTask> newTasks, {bool sort = true}) {
    final newIds = newTasks.map((t) => t.id);
    final l = (tasks ?? []).where((e) => !newIds.contains(e.id)).toList();
    l.addAll(newTasks);
    if (sort) l.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    lastTasksUpdate = DateTime.now();
    tasks = l;
  }

  DateTime get lastMembershipsUpdate => (attributes.containsKey("lu_memberships") && attributes["lu_memberships"] != null) ? DateTime.parse(attributes["lu_memberships"]) : DateTime(1900);
  set lastMembershipsUpdate(DateTime val) => attributes["lu_memberships"] = val.toIso8601String();
  Duration get lastMembershipsUpdateDiff => lastMembershipsUpdate.difference(DateTime.now()).abs();
  /// Liste der Mitgliedschaften in Kursen/Klassen bzw. Gruppen
  List<LSMembership>? get memberships => attributes["memberships"];
  set memberships(List<LSMembership>? val) => _setSaveNotify("memberships", val);

  DateTime get lastMailFoldersUpdate => (attributes.containsKey("lu_mail_folders") && attributes["lu_mail_folders"] != null) ? DateTime.parse(attributes["lu_mail_folders"]) : DateTime(1900);
  set lastMailFoldersUpdate(DateTime val) => attributes["lu_mail_folders"] = val.toIso8601String();
  Duration get lastMailFoldersUpdateDiff => lastMailFoldersUpdate.difference(DateTime.now()).abs();
  List<LSMailFolder>? get mailFolders => attributes["mail_folders"];
  set mailFolders(List<LSMailFolder>? val) => _setSaveNotify("mail_folders", val);

  DateTime get lastMailListingsUpdate => (attributes.containsKey("lu_mail_listings") && attributes["lu_mail_listings"] != null) ? DateTime.parse(attributes["lu_mail_listings"]) : DateTime(1900);
  set lastMailListingsUpdate(DateTime val) => attributes["lu_mail_listings"] = val.toIso8601String();
  Duration get lastMailListingsUpdateDiff => lastMailListingsUpdate.difference(DateTime.now()).abs();
  List<LSMailListing>? get mailListings => attributes["mail_listings"];
  set mailListings(List<LSMailListing>? val) => _setSaveNotify("mail_listings", val?..sort((ml1, ml2) => ml2.date.compareTo(ml1.date)));

  /// This doesn't have a "last update" value, because (lernsax) mails can never change.
  /// And they never will. (hopefully :|)
  List<LSMail> get mailCache => attributes["mails"] ?? [];
  set mailCache(List<LSMail> val) => _setSaveNotify("mails", val);
  void addMailToCache(LSMail mail) {
    final l = mailCache;
    if (l.any((m) => m.id == mail.id && m.folderId == mail.folderId)) return;
    l.add(mail);
    mailCache = l;
  }
  LSMail? getCachedMail(String folderId, int mailId)
    => mailCache.cast<LSMail?>().firstWhere((ml) => ml!.id == mailId && ml.folderId == folderId, orElse: () => null);

  void clearData() {
    final d0 = DateTime(1900);
    lastMailFoldersUpdate = d0;
    mailFolders = null;
    lastMailListingsUpdate = d0;
    mailListings = null;
    lastMembershipsUpdate = d0;
    memberships = null;
    lastNotificationsUpdate = d0;
    notifications = null;
    lastTasksUpdate = d0;
    tasks = null;
    mailCache = [];
  }

  final _serializer = Serializer();
  bool loaded = false;
  final Lock _fileLock = Lock();
  Future<void> save() async {
    if (_fileLock.locked) log("The file lock for LernSaxData (file: cache/$lernSaxDataPrefsKey-data.json) is still locked!!! This means waiting...");
    _fileLock.synchronized(() async => await writeFile(await lernSaxDataFilePath, _serialize()));
  }
  // lernsax always returns CRLF-s as line endings but the dart JSON lib can't seem to decode it after it's been encoded
  String _serialize() => _serializer.serialize(this).replaceAll("\r", "").replaceAll("\t", "");
  void loadFromJson(String json) {
    try {
      _serializer.deserialize(json, this);
    } catch (e, s) {
      log("Error while decoding json for LernSaxData from file:", error: e, stackTrace: s);
      logCatch("ls_data", e, s);
      return;
    }
    loaded = true;
  }
}

/// Systembenachrichtigung auf LernSax
class LSNotification extends SerializableObject {
  String get id => attributes["id"];
  set id(String val) => attributes["id"] = val;

  DateTime get date => DateTime.parse(attributes["date"]);
  set date(DateTime val) => attributes["date"] = val.toIso8601String();

  /// interne ID der Nachricht (wahrscheinlich für Übersetzungen? Bedeutung der IDs unbekannt)
  String get messageTypeId => attributes["messageTypeId"];
  set messageTypeId(String val) => attributes["messageTypeId"] = val;

  /// Inhalt/Beschreibung der Nachricht
  String get message => attributes["message"];
  set message(String val) => attributes["message"] = val;

  /// weitere Daten von LernSax, variiert je nach "object" (etwa Absender für Mail oder Dateiname bei Upload)
  String? get data => attributes["data"];
  set data(String? val) => attributes["data"] = val;

  /// eher from.login -> Login des Absenders, falls vorhanden
  String? get fromUserLogin => attributes["fromUserLogin"];
  set fromUserLogin(String? val) => attributes["fromUserLogin"] = val; // may be empty

  /// Benutzername des Absenders, falls vorhanden
  String? get fromUserName => attributes["fromUserName"];
  set fromUserName(String? val) => attributes["fromUserName"] = val; // may be empty

  /// Login der Absender-/Verursachergruppe, falls vorhanden
  String? get fromGroupLogin => attributes["fromGroupLogin"];
  set fromGroupLogin(String? val) => attributes["fromGroupLogin"] = val; // may be empty

  /// Name der Absender-/Verursachergruppe, falls vorhanden
  String? get fromGroupName => attributes["fromGroupName"];
  set fromGroupName(String? val) => attributes["fromGroupName"] = val; // may be empty

  bool get unread => attributes["unread"];
  set unread(bool val) => attributes["unread"] = val;

  /// auf welche LernSax-Funktion bezieht sich die Benachrichtigung (z.B. "mail")
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

/// Aufgabe
class LSTask extends SerializableObject {
  String get id => attributes["id"];
  set id(String val) => attributes["id"] = val;

  // containsKey will always be true if ... != null is true, but the code is more readable this way imo
  // (and the performance also doesn't matter)
  DateTime? get startDate => (attributes.containsKey("start_date") && attributes["start_date"] != null) ? DateTime.parse(attributes["start_date"]) : null;
  set startDate(DateTime? val) => attributes["start_date"] = val?.toIso8601String();

  DateTime? get dueDate => (attributes.containsKey("due_date") && attributes["due_date"] != null) ? DateTime.parse(attributes["due_date"]) : null;
  set dueDate(DateTime? val) => attributes["due_date"] = val?.toIso8601String();

  /// falls null = persönliche Aufgabe, sonst Aufgabe in Kurs/Gruppe mit diesem Login
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

/// Typ eines Objektes, in dem man Mitglied sein kann
/// 
/// Achtung: wie vieles in der API ist die Bedeutung der Rückgabewerte nicht erläutert. Ich habe diese Zuordnung
/// an den Rückgabewerten festgestellt - es könnte natürlich sein, dass andere Werte noch andere Bedeutungen haben.
enum MembershipType {
  /// Institution = Schule, etwa info@jkgc.lernsax.de
  institution,
  /// Gruppe = dynamischere Klasse, Benutzer könnten frei beitreten/verlassen
  group,
  /// Klasse bzw. Kurs für ein Unterrichtsfach oder allgemein
  class_,
  /// alle anderen Werte, die von der API zurückgegeben werden und die ich nicht zuordnen kann
  unknown;
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

/// Mitgliedschaft in einem Kurs/Gruppe
class LSMembership extends SerializableObject {
  /// Login des Kurses
  String get login => attributes["login"];
  set login(String val) => attributes["login"] = val;

  // from the api json response value with key "name_hr", which could actually mean name - human readable
  // (see here: https://chat.openai.com/share/0191513f-d6ae-466f-acdc-df70e0b2c0bf)
  String get name => attributes["name"];
  set name(String val) => attributes["name"] = val;

  MembershipType get type => MembershipType.fromInt(attributes["type"]);
  set type(MembershipType val) => attributes["type"] = val.toInt();

  /// Rechte des Benutzers
  /// 
  /// vielleicht allgemeine verfügbare Berechtigungen für diesen Kurs?
  List<String> get baseRights => attributes["base_rights"];
  set baseRights(List<String> val) => attributes["base_rights"] = val;

  /// andere Rechte des Benutzers
  /// 
  /// vielleicht die Berechtigungen von Mitgliedern im Kurs?
  List<String> get memberRights => attributes["member_rights"];
  set memberRights(List<String> val) => attributes["member_rights"] = val;

  /// nochmal andere Rechte des Benutzers
  /// 
  /// wahrscheinlich die Berechtigungen, die der Benutzer tatsächlich im Kurs besitzt
  List<String> get effectiveRights => attributes["effective_rights"];
  set effectiveRights(List<String> val) => attributes["effective_rights"] = val;

  LSMembership({
    required String login,
    required String name,
    required List<String> baseRights,
    required List<String> memberRights,
    required List<String> effectiveRights,
    required MembershipType type,
  }) {
    _setup();

    this.login = login;
    this.name = name;
    this.baseRights = baseRights;
    this.memberRights = memberRights;
    this.effectiveRights = effectiveRights;
    this.type = type;
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
    return 'LSMembership('
        'login: $login,'
        ' name: $name,'
        ' baseRights: $baseRights,'
        ' memberRights: $memberRights,'
        ' effectiveRights: $effectiveRights'
        ')';
  }
}

/// Inhalt der Datei Kepler-App-Daten.json im entsprechenden Ordner
class LSAppData {
  final String host;
  final String user;
  final String password;
  final String lastUpdate;
  final bool isTeacherData;

  LSAppData({required this.host, required this.user, required this.password, required this.lastUpdate, required this.isTeacherData});

  @override
  String toString() {
    return "LSAppData(host: $host, user: $user, password: $password, lastUpdate: $lastUpdate, isTeacherData: $isTeacherData)";
  }
}

/// Ordner für Emails
class LSMailFolder extends SerializableObject {
  String get id => attributes["id"];
  set id(String val) => attributes["id"] = val;

  String get name => attributes["name"];
  set name(String val) => attributes["name"] = val;

  bool get isInbox => attributes["is_inbox"];
  set isInbox(bool val) => attributes["is_inbox"] = val;

  bool get isTrash => attributes["is_trash"];
  set isTrash(bool val) => attributes["is_trash"] = val;

  bool get isDrafts => attributes["is_drafts"];
  set isDrafts(bool val) => attributes["is_drafts"] = val;

  bool get isSent => attributes["is_sent"];
  set isSent(bool val) => attributes["is_sent"] = val;

  DateTime get lastModified => DateTime.parse(attributes["lastModified"]);
  set lastModified(DateTime val) => attributes["lastModified"] = val.toIso8601String();

  LSMailFolder({
    required String id,
    required String name,
    required bool isInbox,
    required bool isTrash,
    required bool isDrafts,
    required bool isSent,
    required DateTime lastModified
  }) {
    this.id = id;
    this.name = name;
    this.isInbox = isInbox;
    this.isTrash = isTrash;
    this.isDrafts = isDrafts;
    this.isSent = isSent;
    this.lastModified = lastModified;
  }

  LSMailFolder.data(Map<String, dynamic> data) {
    Serializer().deserialize(jsonEncode(data), this);
  }

  @override
  String toString() {
    return 'LSMailFolder(id: $id, name: $name, isInbox: $isInbox, isTrash: $isTrash, isDrafts: $isDrafts, isSent: $isSent, lastModified: $lastModified)';
  }
}

/// Adressierbares Objekt auf LernSax, wird von API so zurückgegeben um Name und Login zu vereinigen
class LSMailAddressable extends SerializableObject {
  String get address => attributes["address"];
  set address(String val) => attributes["address"] = val;

  /// kann "" sein
  String get name => attributes["name"];
  set name(String val) => attributes["name"] = val;

  LSMailAddressable({
    required String address,
    required String name
  }) {
    this.address = address;
    this.name = name;
  }

  LSMailAddressable.data(Map<String, dynamic> data) {
    Serializer().deserialize(jsonEncode(data), this);
  }

  LSMailAddressable.fromLSApiData(Map<String, String> val) {
    address = val["addr"]!;
    name = val["name"]!;
  }

  static List<LSMailAddressable> fromLSApiDataList(List<dynamic> val)
    => val.cast<Map<String, dynamic>>().where((val) => val["addr"] != null && val["name"] != null).map((val) => LSMailAddressable.fromLSApiData(val.cast())).toList();

  @override
  String toString() {
    return 'LSMailAddressable(address: $address, name: $name)';
  }
}

/// Mail-Auflistungseintrag, wie LSMail nur mit weniger Informationen (keinen Inhalt, keine Anhänge)
class LSMailListing extends SerializableObject {
  int get id => attributes["id"];
  set id(int val) => attributes["id"] = val;

  String get subject => attributes["subject"];
  set subject(String val) => attributes["subject"] = val;

  bool get isUnread => attributes["is_unread"];
  set isUnread(bool val) => attributes["is_unread"] = val;

  /// hat der Benutzer die Mail auf LernSax mit einem Sternchen markiert?
  bool get isFlagged => attributes["is_flagged"];
  set isFlagged(bool val) => attributes["is_flagged"] = val;

  bool get isAnswered => attributes["is_answered"];
  set isAnswered(bool val) => attributes["is_answered"] = val;

  bool get isDeleted => attributes["is_deleted"];
  set isDeleted(bool val) => attributes["is_deleted"] = val;

  DateTime get date => DateTime.parse(attributes["date"]);
  set date(DateTime val) => attributes["date"] = val.toIso8601String();

  int get size => attributes["size"];
  set size(int val) => attributes["size"] = val;

  /// determined by checking if it's in the drafts folder
  /// -> wird so nicht in der API zurückgegeben
  bool get isDraft => attributes["is_draft"];
  set isDraft(bool val) => attributes["is_draft"] = val;

  /// determined by checking if it's in the sent folder
  /// -> wird so nicht von der API zurückgegeben
  bool get isSent => attributes["is_sent"];
  set isSent(bool val) => attributes["is_sent"] = val;

  /// depends on if the message is a draft (then: read from "to") or a received message (then: read from "from")
  List<LSMailAddressable> get addressed => attributes["addressed"];
  set addressed(List<LSMailAddressable> val) => attributes["addressed"] = val;

  String get folderId => attributes["folder_id"];
  set folderId(String val) => attributes["folder_id"] = val;

  LSMailListing({
    required int id,
    required String subject,
    required bool isUnread,
    required bool isFlagged,
    required bool isAnswered,
    required bool isDeleted,
    required DateTime date,
    required int size,
    required List<LSMailAddressable> addressed,
    required bool isDraft,
    required bool isSent,
    required String folderId,
  }) {
    _setup();

    this.id = id;
    this.subject = subject;
    this.isUnread = isUnread;
    this.isFlagged = isFlagged;
    this.isAnswered = isAnswered;
    this.isDeleted = isDeleted;
    this.date = date;
    this.size = size;
    this.addressed = addressed;
    this.isDraft = isDraft;
    this.isSent = isSent;
    this.folderId = folderId;
  }

  LSMailListing.data(Map<String, dynamic> data) {
    _setup();

    Serializer().deserialize(jsonEncode(data), this);
  }

  void _setup() {
    objectCreators["addressed"] = (_) => <LSMailAddressable>[];
    objectCreators["addressed.value"] = (data) => data != null ? LSMailAddressable.data(data) : null;
  }

  @override
  String toString() {
    return 'LSMailListing(id: $id, subject: $subject, isUnread: $isUnread, isFlagged: $isFlagged, isAnswered: $isAnswered, isDeleted: $isDeleted, date: $date, from: $addressed)';
  }
}

/// Anhang an eine Mail
class LSMailAttachment extends SerializableObject {
  String get id => attributes["id"];
  set id(String val) => attributes["id"] = val;

  String get name => attributes["name"];
  set name(String val) => attributes["name"] = val;

  int get size => attributes["size"];
  set size(int val) => attributes["size"] = val;

  LSMailAttachment({
    required String id,
    required String name,
    required int size,
  }) {
    this.id = id;
    this.name = name;
    this.size = size;
  }
  
  LSMailAttachment.data(Map<String, dynamic> data) {
    Serializer().deserialize(jsonEncode(data), this);
  }

  LSMailAttachment.fromLSApiData(Map<String, dynamic> val) {
    id = val["id"]!;
    name = val["name"]!;
    size = val["size"]!;
  }

  static List<LSMailAttachment> fromLSApiDataList(List<dynamic> val)
    => val.cast<Map<String, dynamic>>().map((val) => LSMailAttachment.fromLSApiData(val)).toList();

  @override
  String toString() {
    return 'LSMailAttachment(id: $id, name: $name, size: $size)';
  }
}

/// Mail auf LernSax
class LSMail extends SerializableObject {
  int get id => attributes["id"];
  set id(int val) => attributes["id"] = val;

  String get subject => attributes["subject"];
  set subject(String val) => attributes["subject"] = val;

  bool get isUnread => attributes["isUnread"];
  set isUnread(bool val) => attributes["isUnread"] = val;

  bool get isFlagged => attributes["isFlagged"];
  set isFlagged(bool val) => attributes["isFlagged"] = val;

  bool get isAnswered => attributes["isAnswered"];
  set isAnswered(bool val) => attributes["isAnswered"] = val;

  bool get isDeleted => attributes["isDeleted"];
  set isDeleted(bool val) => attributes["isDeleted"] = val;

  DateTime get date => DateTime.parse(attributes["date"]);
  set date(DateTime val) => attributes["date"] = val.toIso8601String();

  int get size => attributes["size"];
  set size(int val) => attributes["size"] = val;

  String get bodyPlain => attributes["bodyPlain"];
  set bodyPlain(String val) => attributes["bodyPlain"] = val;

  List<LSMailAddressable> get from => attributes["from"];
  set from(List<LSMailAddressable> val) => attributes["from"] = val;

  List<LSMailAddressable> get to => attributes["to"];
  set to(List<LSMailAddressable> val) => attributes["to"] = val;

  List<LSMailAddressable> get replyTo => attributes["replyTo"];
  set replyTo(List<LSMailAddressable> val) => attributes["replyTo"] = val;

  List<LSMailAttachment> get attachments => attributes["attachments"];
  set attachments(List<LSMailAttachment> val) => attributes["attachments"] = val;

  String get folderId => attributes["folder_id"];
  set folderId(String val) => attributes["folder_id"] = val;

  LSMail({
    required int id,
    required String subject,
    required bool isUnread,
    required bool isFlagged,
    required bool isAnswered,
    required bool isDeleted,
    required DateTime date,
    required int size,
    required String bodyPlain,
    required List<LSMailAddressable> from,
    required List<LSMailAddressable> to,
    required List<LSMailAddressable> replyTo,
    required List<LSMailAttachment> attachments,
    required String folderId,
  }) {
    _setup();

    this.id = id;
    this.subject = subject;
    this.isUnread = isUnread;
    this.isFlagged = isFlagged;
    this.isAnswered = isAnswered;
    this.isDeleted = isDeleted;
    this.date = date;
    this.size = size;
    this.bodyPlain = bodyPlain;
    this.from = from;
    this.to = to;
    this.replyTo = replyTo;
    this.attachments = attachments;
    this.folderId = folderId;
  }

  LSMail.data(Map<String, dynamic> data) {
    _setup();

    Serializer().deserialize(jsonEncode(data), this);
  }
  
  void _setup() {
    objectCreators["from"] = (_) => <LSMailAddressable>[];
    objectCreators["from.value"] = (data) => data != null ? LSMailAddressable.data(data) : null;
    objectCreators["to"] = (_) => <LSMailAddressable>[];
    objectCreators["to.value"] = (data) => data != null ? LSMailAddressable.data(data) : null;
    objectCreators["replyTo"] = (_) => <LSMailAddressable>[];
    objectCreators["replyTo.value"] = (data) => data != null ? LSMailAddressable.data(data) : null;
    objectCreators["attachments"] = (_) => <LSMailAttachment>[];
    objectCreators["attachments.value"] = (data) => data != null ? LSMailAttachment.data(data) : null;
  }
}


/// enum value name is the string that the ls api returns for mode in mailbox.get_state
enum LSMailMode {
  /// can only send mails to other @school.lernsax.de mail addresses
  local,
  // warning: the name "platform" is just a guess, I have no access to a lernsax account that can only send mails
  // to other accounts on lernsax
  /// can only send mails to other @*lernsax.de mail addresses
  platform,
  /// can send mails to everyone
  global,
  unknown;

  static LSMailMode fromString(String val) => LSMailMode.values.where((v) => v.name == val).toList().firstOrNull ?? LSMailMode.unknown;
}

// this isn't a serializable because this really doesn't need to be available offline
class LSMailState {
  final int usageBytes;
  final int freeBytes;
  final int limitBytes;
  final int unreadMessages;
  final LSMailMode mode;

  LSMailState({required this.usageBytes, required this.freeBytes, required this.limitBytes, required this.unreadMessages, required this.mode});
}

/// um einen Anhang herunterzuladen, muss er in eine Session-Datei übertragen werden - dabei bekommt man diese
/// Daten zurückgegeben
class LSSessionFile {
  final String id;
  final String name;
  final int size;
  final String downloadUrl;

  const LSSessionFile({required this.id, required this.name, required this.size, required this.downloadUrl});
}

/// Benachrichtigungseinstellungen für einen Kurs oder den Benutzer, wenn `classLogin == null`
class LSNotifSettings {
  final int id;
  final String? classLogin;
  final String name;
  final String object;
  final List<String> enabledFacilities;
  final List<String> disabledFacilities;

  const LSNotifSettings({required this.id, required this.classLogin, required this.name, required this.object, required this.enabledFacilities, required this.disabledFacilities});
}
