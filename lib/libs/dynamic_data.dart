import 'dart:convert';

import 'package:kepler_app/build_vars.dart';
import 'package:http/http.dart' as http;
import 'package:kepler_app/libs/logging.dart';

const supportedMajorServerVersion = 1;

typedef DynStatusData = ({ String serviceName, DynVersionData version, DynAppVersionData appVersion, Map<String, DynServiceData> services });
typedef DynVersionData = ({ String string, int major, int minor, int patch });
typedef DynAppVersionData = ({ String name, int code });
typedef DynServiceData = ({ bool available });

class DynamicData {
  DynamicData._();

  static const bool available = kDynamicDataHost != null;
  static Uri _ddUri(String path) => Uri.parse("https://$kDynamicDataHost$path");

  static DynStatusData? _status;
  static DynStatusData? get status => _status;
  static bool enabled = false;
  static bool serverTooNew = false;

  static Future<bool> init() async {
    enabled = false;
    serverTooNew = false;
    if (!available) return false;

    final dynamic json;
    try {
      final data = await (http.get(_ddUri("/data/status")).timeout(const Duration(seconds: 3)));
      if (data.statusCode != 200) return false;
      json = jsonDecode(data.body);
    } on Exception catch (e, s) {
      logCatch("dyndata-fetch", e, s);
      return false;
    }

    try {
      _status = (
        serviceName: json["service"],
        version: (
          string: json["version"]["string"],
          major: json["version"]["major"],
          minor: json["version"]["minor"],
          patch: json["version"]["patch"],
        ),
        appVersion: (
          code: json["app_version"]["code"],
          name: json["app_version"]["name"],
        ),
        services: Map.fromEntries((json["services"] as Map<dynamic, dynamic>).keys.map((key) => MapEntry(key, (available: json["services"][key]["available"] as bool))))
      );

      if (status?.serviceName != "dyn_kepapp_data") return false;

      serverTooNew = status!.version.major > supportedMajorServerVersion;
      enabled = true;
    } on Exception catch (e, s) {
      logCatch("dyndata-json", e, s);
      return false;
    }
    return true;
  }

  static Future<Map<String, dynamic>?> getSommerfestData() async {
    if (!enabled) await init();
    if (!enabled || !available) return null;
    if (status?.services.containsKey("sommerfest") != true || status?.services["sommerfest"]?.available != true) return null;

    final Map<String, dynamic>? json;
    try {
      final data = (await http.get(_ddUri("/data/sommerfest.json")));
      if (data.statusCode != 200) return null;
      json = jsonDecode(utf8.decode(data.bodyBytes));
    } on Exception catch (e, s) {
      logCatch("dyndata-fetch", e, s);
      return null;
    }

    return json;
  }

  static bool isServiceAvailable(String name) {
    if (!enabled || !available || status == null) return false;
    return status?.services.containsKey(name) == true && status?.services[name]?.available == true;
  }
}
