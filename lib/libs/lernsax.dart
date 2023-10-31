import "dart:convert";
import "dart:developer";
import "dart:io";

import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import 'package:crypto/crypto.dart' as crypto;
import "package:intl/intl.dart";
import "package:kepler_app/tabs/lernsax/ls_data.dart";

//
// Info to the function comments:
// "isOnline" actually means "can connect to lernsax servers", but that'll mean the same (hopefully) most of the time.
//

const url = "https://www.lernsax.de/jsonrpc.php";
final uri = Uri.parse(url);
// this salt was generated by ChatGPT: https://chat.openai.com/share/74277f02-553d-44a7-9812-111294e6089d
const salt = "The secure salt for this cryptographic operation, 'mYk3v1nS@lt2023', ensures the protection of sensitive data";
const appID = "keplerapp";
const appTitle = "Kepler-App";

class LernSaxException implements Exception {
  final String message;

  LernSaxException(this.message);

  @override
  String toString() => message;
}

Map<String, dynamic> call({required String method, Map<String, dynamic>? params, int? id}) =>
    {
      "jsonrpc": "2.0",
      "method": method,
      if (params != null) "params": params,
      if (id != null) "id": id,
    };

Map<String, dynamic> focus(String object, { String? login }) => call(method: "set_focus", params: {
  "object": object,
  if (login != null) "login" : login,
});

String sha1(String input) {
  final bytes = utf8.encode(input);
  final digest = crypto.sha1.convert(bytes);
  return digest.toString();
}

bool toBool(dynamic input) => (input is num && input > 0) || (input is bool && input) || (input is String && input.isNotEmpty);

/// returns: isOnline, data
Future<(bool, Map<String, dynamic>?)> auth(String mail, String token, {int? id}) async {
  final (online, res) = (await api([call(method: "get_nonce", id: 1)]));
  if (!online) return (false, null);
  final nonce = res[0]["result"];
  if (nonce["return"] == "OK" && nonce["nonce"] != null) {
    final hash = sha1("${nonce["nonce"]["key"]}$salt$token");
    return (true, call(
      method: "login",
      params: {
        "login": mail,
        "algorithm": "sha1",
        "nonce_id": nonce["nonce"]["id"],
        "salt": salt,
        "hash": hash,
        "application": appID,
        "get_properties": [],
        "is_online": 0,
      },
      id: id,
    ));
  } else {
    throw LernSaxException("get_nonce failed");
  }
}

/// returns: isOnline, data
Future<(bool, String)> newSession(String mail, String token, int durationSeconds) async {
  final (online1, authres) = await auth(mail, token);
  if (!online1 || authres == null) return (false, "");
  final (online2, res) = await api([
    authres,
    call(method: "set_options", params: {"session_timeout": durationSeconds}),
    call(method: "get_information", id: 1),
  ]);
  if (!online2) return (false, "");
  final result = res[0]["result"];
  return (true, result["session_id"] as String);
}

String _currentSessionId = "";
DateTime _lastSessionUpdate = DateTime(1900);
const _timeTilRefresh = Duration(minutes: 15);
String durform(Duration dur) => "${dur.inMinutes.abs()}m${dur.inSeconds % 60}s";
/// returns: isOnline, data
Future<(bool, String)> session(String mail, String token) async {
  if (kDebugMode) print("[LS-AuthDebug] current sesh: $_currentSessionId, last update: ${DateFormat.Hms().format(_lastSessionUpdate)}, time to update: ${durform(_lastSessionUpdate.difference(DateTime.now().subtract(_timeTilRefresh)))}, update now: ${_lastSessionUpdate.difference(DateTime.now()).abs() >= _timeTilRefresh}");
  if (_lastSessionUpdate.difference(DateTime.now()).abs() >= _timeTilRefresh) {
    final (online, newSesId) = await newSession(mail, token, (_timeTilRefresh + const Duration(seconds: 30)).inSeconds);
    if (!online) return (false, "");
    _currentSessionId = newSesId;
    _lastSessionUpdate = DateTime.now();
  }
  return (true, _currentSessionId);
}

// this never needs an ID, because the response from the API for set_session doesn't contain the login information
Future<Map<String, dynamic>> useSession(String login, String token) async =>
    call(
        method: "set_session",
        // even though this ignores the "online" status, it still will cause an error in the place where useSession is used (because session.$2 will be empty)
        // and because the next function will return with online = false most likely anyway if online is false here, it's fine imo to ignore it here
        params: {"session_id": (await session(login, token)).$2});

/// returns: isOnline, data
Future<(bool, dynamic)> api(List<Map<String, dynamic>> data) async => await http
    .post(
      uri,
      headers: {"content-type": "application/json"},
      body: jsonEncode(data),
    )
    .then((res) => (true, jsonDecode(utf8.decode(res.bodyBytes))))
    .catchError((_) => (false, null));

const keplerBaseUser = "info@jkgc.lernsax.de";
const keplerTeacherBaseUser = "lehrer@jkgc.lernsax.de";
const keplerAppFolderName = "Kepler-App";
const keplerAppJsonFileName = "Kepler-App-Daten.json";

enum MOJKGResult {
  allGood,
  invalidLogin,
  noJKGMember,
  otherError,
  invalidResponse
}

/// returns: isOnline, data
Future<(bool, MOJKGResult)> isMemberOfJKG(String mail, String password) async {
  late final dynamic res;
  try {
    final (online, resInner) = await api([
      call(
        method: "login",
        params: {
          "login": mail,
          "password": password,
          "is_online": 0,
        },
        id: 1,
      ),
      call(method: "logout"),
    ]);
    if (!online) return (false, MOJKGResult.otherError);
    res = resInner;
  } catch (_) {
    return (true, MOJKGResult.otherError);
  }
  return (true, _processMemberResponse(res));
}

MOJKGResult _processMemberResponse(res) {
  try {
    final response = res[0]["result"];
    if (response["return"] == "FATAL") {
      if (response["errno"] == "107") {
        return MOJKGResult.invalidLogin;
      } else {
        return MOJKGResult.otherError;
      }
    } else {
      if (response["user"]["base_user"]["login"] == keplerBaseUser) {
        return MOJKGResult.allGood;
      } else {
        return MOJKGResult.noJKGMember;
      }
    }
  } catch (_) {
    return MOJKGResult.invalidResponse;
  }
}

/// returns: isOnline, data
Future<(bool, String?)> registerApp(String mail, String password) async {
  try {
    final deviceModel = (Platform.isAndroid)
        ? (await DeviceInfoPlugin().androidInfo).model
        : (await DeviceInfoPlugin().iosInfo).model;
    final (online, res) = await api([
      call(
        method: "login",
        params: {
          "login": mail,
          "password": password,
          "is_online": 0,
        },
      ),
      focus("trusts"),
      call(
        method: "register_master",
        params: {
          "remote_application": appID,
          "remote_title": appTitle,
          "remote_ident": deviceModel,
        },
        id: 1,
      ),
      call(method: "logout"),
    ]);
    if (!online) return (false, null);
    final response = res[0]["result"];
    return (true, response["trust"]["token"] as String);
  } catch (_) {
    return (true, null);
  }
}

/// returns: isOnline, data
Future<(bool, bool?)> confirmLernSaxCredentials(String login, String token) async {
  try {
    final (online1, authres) = await auth(login, token, id: 1);
    if (!online1 || authres == null) return (false, null);
    final (online2, res) = await api([
      authres,
      call(method: "logout"),
    ]);
    if (!online2) return (false, null);
    final ret = res[0]["result"]["return"];
    return (true, ret == "OK");
  } catch (_) {
    return (true, null);
  }
}

/// returns: isOnline, data
Future<(bool, String?)> getSingleUseLoginLink(String login, String token) async {
  try {
    final (online, res) = await api([
      await useSession(login, token),
      focus("trusts"),
      call(
        id: 1,
        method: "get_url_for_autologin",
      ),
    ]);
    if (!online) return (false, null);
    // if (kDebugMode) print(res);
    final url = res[0]["result"]["url"];
    return (true, url as String);
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return (true, null);
  }
}

/// returns: isOnline, data
Future<(bool, List<LSNotification>?)> getNotifications(String login, String token, {String? startId}) async {
  try {
    final (online, res) = await api([
      await useSession(login, token),
      focus("messages"),
      call(
        id: 1,
        method: "get_messages",
        params: {
          if (startId != null) "start_id": startId,
        }
      ),
    ]);
    if (!online) return (false, null);
    // if (kDebugMode) print(res);
    final messages = (res[0]["result"]["messages"] as List<dynamic>).cast<Map<String, dynamic>>();
    if (startId != null) messages.removeAt(0);
    return (true, messages.map((data) => LSNotification(
      id: data["id"],
      date: DateTime.fromMillisecondsSinceEpoch(int.parse(data["date"]) * 1000),
      messageTypeId: data["message"],
      message: data["message_hr"],
      fromUserLogin: data["from_user"]["login"],
      fromUserName: data["from_user"]["name_hr"],
      fromGroupLogin: data["from_group"]["login"],
      fromGroupName: data["from_group"]["name_hr"],
      unread: data["unread"] == 1,
      object: data["object"],
      data: data["data"],
    )).toList());
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return (false, null);
  }
}

/// returns: isOnline, data
Future<(bool, List<LSTask>?)> getTasks(String login, String token, {String? classLogin}) async {
  try {
    final (online, res) = await api([
      await useSession(login, token),
      focus("tasks", login: classLogin),
      call(
        id: 1,
        method: "get_entries",
      ),
    ]);
    if (!online) return (false, null);
    // if (kDebugMode) print(res);
    final messages = (res[0]["result"]["entries"] as List<dynamic>).cast<Map<String, dynamic>>();
    return (true, messages.map((data) => LSTask(
      id: data["id"],
      startDate: data["start_date"] != "" ? DateTime.fromMillisecondsSinceEpoch(int.parse(data["start_date"]) * 1000) : null,
      dueDate: data["due_date"] != "" ? DateTime.fromMillisecondsSinceEpoch(int.parse(data["due_date"]) * 1000) : null,
      title: data["title"],
      description: data["description"],
      completed: data["completed"] == 1,
      classLogin: classLogin,
      createdByLogin: data["created"]["user"]["login"],
      createdByName: data["created"]["user"]["name_hr"],
      createdAt: DateTime.fromMillisecondsSinceEpoch(int.parse(data["created"]["date"].toString()) * 1000),
    )).toList());
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return (true, null);
  }
}

/// returns: isOnline, data
Future<(bool, List<LSMembership>?)> getGroupsAndClasses(String login, String token) async {
  try {
    final (online, res) = await api([
      await useSession(login, token),
      call(method: "reload", id: 1, params: { "get_properties": ["member"] }),
    ]);
    if (!online) return (false, null);
    if (res[0]["result"]["return"] != "OK") return (true, null);
    final memberList = res[0]["result"]["member"] as List<dynamic>;
    final list = <LSMembership>[];
    for (final m in memberList) {
      list.add(LSMembership(
        login: m["login"],
        name: m["name_hr"],
        baseRights: m["base_rights"]?.cast<String>() ?? [],
        memberRights: m["member_rights"]?.cast<String>() ?? [],
        effectiveRights: m["effective_rights"]?.cast<String>() ?? [],
        type: MembershipType.fromInt(int.parse((m["type"] ?? -1).toString())),
      ));
    }
    return (true, list);
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return (true, null);
  }
}

/// returns: isOnline, data
Future<(bool, bool?)> isTeacher(String login, String token) async {
  try {
    final (online, memberships) = await getGroupsAndClasses(login, token);
    if (!online) return (false, null);
    if (memberships == null) return (true, null);

    return (true, memberships.any((ms) => ms.login == keplerTeacherBaseUser));
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return (true, null);
  }
}

/// returns: isOnline, data
Future<(bool, bool?)> unregisterApp(String login, String token) async {
  try {
    final (online, authres) = await auth(login, token);
    if (!online) return (false, null);
    final (online2, res) = await api([
      authres!,
      focus("trusts"),
      call(method: "unregister_master", id: 1),
    ]);
    if (!online2) return (false, null);
    return (true, res[0]["result"]["return"] != "OK");
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return (true, null);
  }
}

/// returns: isOnline, data
Future<(bool, LSAppData?)> getLernSaxAppDataJson(String login, String token, bool forTeachers) async {
  try {
    final (online1, res) = await api([
      await useSession(login, token),
      focus("files", login: forTeachers ? keplerTeacherBaseUser : keplerBaseUser),
      call(
        method: "get_entries",
        params: {
          "get_folders": 1,
          "get_files": 0,
          "search_string": keplerAppFolderName,
        },
        id: 1,
      ),
    ]);
    if (!online1) return (false, null);
    if (res[0]["result"]["return"] != "OK" || res[0]["result"]["entries"].length < 1) return (true, null);

    final folderId = res[0]["result"]["entries"][0]["id"];
    final (online2, res2) = await api([
      await useSession(login, token),
      focus("files", login: forTeachers ? keplerTeacherBaseUser : keplerBaseUser),
      call(
        method: "get_entries",
        params: {
          "folder_id": folderId,
          "get_folders": 0,
          "get_files": 1,
          "search_string": keplerAppJsonFileName,
        },
        id: 1,
      ),
    ]);
    if (!online2) return (false, null);
    if (res2[0]["result"]["return"] != "OK" || res2[0]["result"]["entries"].length < 1) return (true, null);

    final fileId = res2[0]["result"]["entries"][0]["id"];
    final (online3, res3) = await api([
      await useSession(login, token),
      focus("files", login: forTeachers ? keplerTeacherBaseUser : keplerBaseUser),
      call(
        method: "get_file",
        params: {
          "id": fileId,
        },
        id: 1,
      ),
    ]);
    if (!online3) return (false, null);
    if (res3[0]["result"]["return"] != "OK" || res3[0]["result"]["file"] == null) return (true, null);

    final dataStr = utf8.decode(base64Decode(res3[0]["result"]["file"]["data"]));
    final data = jsonDecode(dataStr);

    return (true, LSAppData(
      lastUpdate: data["letztes_update"],
      host: data["indiware"]["host"],
      user: data["indiware"]["user"],
      password: data["indiware"]["password"],
      isTeacherData: data["is_teacher_data"],
    ));
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return (true, null);
  }
}

/// returns: isOnline, data
Future<(bool, List<LSMailFolder>?)> getMailFolders(String login, String token) async {
  try {
    final (online, res) = await api([
      await useSession(login, token),
      focus("mailbox"),
      call(method: "get_folders", id: 1),
    ]);
    if (!online) return (false, null);
    if (res[0]["result"]["return"] != "OK") return (true, null);
    return (true, (res[0]["result"]["folders"] as List<dynamic>).map((data) => LSMailFolder(
      id: data["id"],
      name: data["name"],
      isInbox: toBool(data["is_inbox"]),
      isTrash: toBool(data["is_trash"]),
      isDrafts: toBool(data["is_drafts"]),
      isSent: toBool(data["is_sent"]),
      lastModified: DateTime.fromMillisecondsSinceEpoch(data["m_date"] * 1000),
    )).toList());
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return (true, null);
  }
}

/// returns: isOnline, data
Future<(bool, List<LSMailListing>?)> getMailListings(String login, String token, { required String folderId, int? offset, int? limit, bool isDraftsFolder = false, bool isSentFolder = false }) async {
  try {
    final (online, res) = await api([
      await useSession(login, token),
      focus("mailbox"),
      call(
        method: "get_messages",
        params: {
          "folder_id": folderId,
          if (offset != null) "offset": offset,
          if (limit != null) "limit": limit,
        },
        id: 1,
      ),
    ]);
    if (!online) return (false, null);
    if (res[0]["result"]["return"] != "OK") return (true, null);
    return (true, (res[0]["result"]["messages"] as List<dynamic>).map((data) => LSMailListing(
      id: data["id"],
      subject: data["subject"],
      isUnread: toBool(data["is_unread"]),
      isFlagged: toBool(data["is_flagged"]),
      isAnswered: toBool(data["is_answered"]),
      isDeleted: toBool(data["is_deleted"]),
      date: DateTime.fromMillisecondsSinceEpoch(data["date"] * 1000),
      size: data["size"],
      addressed: data.containsKey("from") ? LSMailAddressable.fromLSApiDataList(data["from"]) : data.containsKey("to") ? LSMailAddressable.fromLSApiDataList(data["to"]) : [],
      isDraft: isDraftsFolder,
      isSent: isSentFolder,
      folderId: folderId,
    )).toList());
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return (true, null);
  }
}

/// returns: isOnline, data
Future<(bool, LSMail?)> getMail(String login, String token, { required String folderId, required int mailId, bool peek = false }) async {
  try {
    final (online, res) = await api([
      await useSession(login, token),
      focus("mailbox"),
      call(
        method: "read_message",
        params: {
          "folder_id": folderId,
          "message_id": mailId,
          if (peek) "peek": peek,
        },
        id: 1,
      ),
    ]);
    if (!online) return (false, null);
    if (res[0]["result"]["return"] != "OK") return (true, null);
    final data = res[0]["result"]["message"] as Map<String, dynamic>;
    return (true, LSMail(
      id: data["id"],
      subject: data["subject"],
      isUnread: toBool(data["is_unread"]),
      isFlagged: toBool(data["is_flagged"]),
      isAnswered: toBool(data["is_answered"]),
      isDeleted: toBool(data["is_deleted"]),
      date: DateTime.fromMillisecondsSinceEpoch(data["date"] * 1000),
      size: data["size"],
      bodyPlain: data["body_plain"],
      from: LSMailAddressable.fromLSApiDataList(data["from"]),
      to: LSMailAddressable.fromLSApiDataList(data["to"]),
      replyTo: data.containsKey("reply_to") ? LSMailAddressable.fromLSApiDataList(data["reply_to"]) : [],
      attachments: data.containsKey("files") ? LSMailAttachment.fromLSApiDataList(data["files"]) : [],
      folderId: folderId,
    ));
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return (true, null);
  }
}

/// returns: isOnline, data
Future<(bool, LSMailState?)> getMailState(String login, String token) async {
  try {
    final (online, res) = await api([
      await useSession(login, token),
      focus("mailbox"),
      call(method: "get_state", id: 1),
    ]);
    if (!online) return (false, null);
    if (res[0]["result"]["return"] != "OK") return (true, null);
    final data = res[0]["result"] as Map<String, dynamic>;
    return (true, LSMailState(
      usageBytes: data["quota"]["usage"],
      freeBytes: data["quota"]["free"],
      limitBytes: data["quota"]["limit"],
      mode: LSMailMode.fromString(data["mode"]),
      unreadMessages: data["unread_messages"],
    ));
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return (true, null);
  }
}

Future<(bool, LSSessionFile?)> exportSessionFileFromMail(String login, String token, { required String folderId, required int mailId, required String attachmentId }) async {
  try {
    final (online, res) = await api([
      await useSession(login, token),
      focus("mailbox"),
      call(
        method: "export_session_file",
        params: {
          "folder_id": folderId,
          "message_id": mailId,
          "file_id": attachmentId,
        },
        id: 1,
      ),
    ]);
    if (!online) return (false, null);
    if (res[0]["result"]["return"] != "OK") return (true, null);
    final data = res[0]["result"]["file"] as Map<String, dynamic>;
    return (true, LSSessionFile(
      id: data["id"],
      name: data["name"],
      size: data["size"],
      downloadUrl: data["download_url"],
    ));
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return (true, null);
  }
}
