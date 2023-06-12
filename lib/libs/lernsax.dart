import "dart:convert";
import "dart:io";

import "package:device_info_plus/device_info_plus.dart";
import "package:http/http.dart" as http;
import 'package:crypto/crypto.dart' as crypto;

const url = "https://www.lernsax.de/jsonrpc.php";
final uri = Uri.parse(url);
const salt = "kevin";
const appID = "keplerapp";
const appTitle = "Kepler-App";

class LernSaxException implements Exception {
  final String message;

  LernSaxException(this.message);

  @override
  String toString() => message;
}

Map<String, dynamic> call({required String method, Map<String, dynamic>? params, int? id}) => {
  "jsonrpc": "2.0",
  "method": method,
  if (params != null) "params": params,
  if (id != null) "id": id,
};

String sha1(String input) {
  final bytes = utf8.encode(input);
  final digest = crypto.sha1.convert(bytes);
  return digest.toString();
}

Future<Map<String, dynamic>> auth(String mail, String token, {int? id}) async {
  final nonce = (await api([call(method: "get_nonce", id: 1)]))[0]["result"];
  if (nonce["return"] == "OK" && nonce["nonce"] != null) {
    final hash = sha1("${nonce["nonce"]}$salt$token");
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
        "is_online": false,
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
Future<String> session(String mail, String token) async {
  if (_lastSessionUpdate.difference(DateTime.now()) >= _timeTilRefresh) {
    _currentSessionId = await newSession(mail, token, (_timeTilRefresh + const Duration(seconds: 30)).inSeconds);
    _lastSessionUpdate = DateTime.now();
  }
  return _currentSessionId;
}
Future<Map<String, dynamic>> useSession(String mail, String token) async
  => call(method: "set_session", params: {"session_id": await session(mail, token)});

Future<dynamic> api(List<Map<String, dynamic>> data) async
  => await http.post(uri, headers: {
    "content-type": "application/json"
  }, body: jsonEncode(data),)
  .then((res) => jsonDecode(res.body));

const keplerBaseUser = "info@jkgc.lernsax.de";
enum MOJKGResult { allGood, invalidLogin, noJKGMember, otherError, invalidResponse }
Future<MOJKGResult> isMemberOfJKG(String mail, String password) async {
  final res = await api([
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
  final deviceModel = (Platform.isAndroid) ? (await DeviceInfoPlugin().androidInfo).model : (await DeviceInfoPlugin().iosInfo).model;
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
      params: {
        "object": "trusts"
      },
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
