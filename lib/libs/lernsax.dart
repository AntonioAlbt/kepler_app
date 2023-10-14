import "dart:convert";
import "dart:developer";
import "dart:io";

import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import 'package:crypto/crypto.dart' as crypto;
import "package:intl/intl.dart";
import "package:kepler_app/tabs/lernsax/ls_data.dart";

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
      // "id": 2 + Random.secure().nextInt(1000)
    };

String sha1(String input) {
  final bytes = utf8.encode(input);
  final digest = crypto.sha1.convert(bytes);
  return digest.toString();
}

Future<Map<String, dynamic>> auth(String mail, String token, {int? id}) async {
  final nonce = (await api([call(method: "get_nonce", id: 1)]))[0]["result"];
  if (nonce["return"] == "OK" && nonce["nonce"] != null) {
    final hash = sha1("${nonce["nonce"]["key"]}$salt$token");
    return call(
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
    );
  } else {
    throw LernSaxException("get_nonce failed");
  }
}

Future<String> newSession(String mail, String token, int durationSeconds) async {
  final res = await api([
    await auth(mail, token),
    call(method: "set_options", params: {"session_timeout": durationSeconds}),
    call(method: "get_information", id: 1),
  ]);
  final result = res[0]["result"];
  return result["session_id"];
}

String _currentSessionId = "";
DateTime _lastSessionUpdate = DateTime(1900);
const _timeTilRefresh = Duration(minutes: 15);
String durform(Duration dur) => "${dur.inMinutes.abs()}m${dur.inSeconds % 60}s";
Future<String> session(String mail, String token) async {
  if (kDebugMode) print("[LS-AuthDebug] current sesh: $_currentSessionId, last update: ${DateFormat.Hms().format(_lastSessionUpdate)}, time to update: ${durform(_lastSessionUpdate.difference(DateTime.now().subtract(_timeTilRefresh)))}, update now: ${_lastSessionUpdate.difference(DateTime.now()).abs() >= _timeTilRefresh}");
  if (_lastSessionUpdate.difference(DateTime.now()).abs() >= _timeTilRefresh) {
    _currentSessionId = await newSession(mail, token, (_timeTilRefresh + const Duration(seconds: 30)).inSeconds);
    _lastSessionUpdate = DateTime.now();
  }
  return _currentSessionId;
}

// this never needs an ID, because the response from the API for set_session doesn't contain the login information
Future<Map<String, dynamic>> useSession(String mail, String token) async =>
    call(
        method: "set_session",
        params: {"session_id": await session(mail, token)});

Future<dynamic> api(List<Map<String, dynamic>> data) async => await http
    .post(
      uri,
      headers: {"content-type": "application/json"},
      body: jsonEncode(data),
    )
    .then((res) => jsonDecode(utf8.decode(res.bodyBytes)));

const keplerBaseUser = "info@jkgc.lernsax.de";

enum MOJKGResult {
  allGood,
  invalidLogin,
  noJKGMember,
  otherError,
  invalidResponse
}

Future<MOJKGResult> isMemberOfJKG(String mail, String password) async {
  late final dynamic res;
  try {
    res = await api([
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
  } catch (_) {
    return MOJKGResult.otherError;
  }
  return _processMemberResponse(res);
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

Future<String> registerApp(String mail, String password) async {
  final deviceModel = (Platform.isAndroid)
      ? (await DeviceInfoPlugin().androidInfo).model
      : (await DeviceInfoPlugin().iosInfo).model;
  final res = await api([
    call(
      method: "login",
      params: {
        "login": mail,
        "password": password,
        "is_online": 0,
      },
    ),
    call(
      method: "set_focus",
      params: {"object": "trusts"},
    ),
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
  final response = res[0]["result"];
  return response["trust"]["token"];
}

Future<bool?> confirmLernSaxCredentials(String login, String token) async {
  try {
    final res = await api([
      await auth(login, token, id: 1),
      call(method: "logout"),
    ]);
    final ret = res[0]["result"]["return"];
    return ret == "OK";
  } catch (_) {
    return null;
  }
}

Future<String?> getSingleUseLoginLink(String login, String token) async {
  try {
    final res = await api([
      await useSession(login, token),
      call(
        method: "set_focus",
        params: {"object": "trusts"},
      ),
      call(
        id: 1,
        method: "get_url_for_autologin",
      ),
    ]);
    // if (kDebugMode) print(res);
    final url = res[0]["result"]["url"];
    return url;
  } catch (e) {
    return null;
  }
}

Future<List<LSNotification>?> getNotifications(String login, String token, {String? startId}) async {
  try {
    final res = await api([
      await useSession(login, token),
      call(
        method: "set_focus",
        params: {"object": "messages"},
      ),
      call(
        id: 1,
        method: "get_messages",
        params: {
          if (startId != null) "start_id": startId,
        }
      ),
    ]);
    // if (kDebugMode) print(res);
    final messages = (res[0]["result"]["messages"] as List<dynamic>).cast<Map<String, dynamic>>();
    if (startId != null) messages.removeAt(0);
    return messages.map((data) => LSNotification(
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
    )).toList();
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return null;
  }
}

Future<List<LSTask>?> getTasks(String login, String token, {String? classLogin}) async {
  try {
    final res = await api([
      await useSession(login, token),
      call(
        method: "set_focus",
        params: {
          "object": "tasks",
          if (classLogin != null) "login": classLogin,
        },
      ),
      call(
        id: 1,
        method: "get_entries",
      ),
    ]);
    // if (kDebugMode) print(res);
    final messages = (res[0]["result"]["entries"] as List<dynamic>).cast<Map<String, dynamic>>();
    return messages.map((data) => LSTask(
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
    )).toList();
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return null;
  }
}

Future<List<LSMembership>?> getGroupsAndClasses(String login, String token) async {
  try {
    final res = await api([
      await useSession(login, token),
      call(method: "reload", id: 1, params: { "get_properties": ["member"] }),
    ]);
    if (res[0]["result"]["return"] != "OK") return null;
    final memberList = res[0]["result"]["member"] as List<dynamic>;
    final list = <LSMembership>[];
    for (final m in memberList) {
      list.add(LSMembership(
        login: m["login"],
        name: m["name_hr"],
        baseRights: m["base_rights"]?.cast<String>() ?? [],
        memberRights: m["member_rights"]?.cast<String>() ?? [],
        effectiveRights: m["effective_rights"]?.cast<String>() ?? [],
      ));
    }
    return list;
  } catch (e, s) {
    if (kDebugMode) log("", error: e, stackTrace: s);
    return null;
  }
}
