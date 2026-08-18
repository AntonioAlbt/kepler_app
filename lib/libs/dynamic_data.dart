// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2023-2026 Antonio Albert

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
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:http/http.dart' as http;
import 'package:kepler_app/libs/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
      final pkg = await PackageInfo.fromPlatform();
      final osVer = Platform.isAndroid ? (await DeviceInfoPlugin().androidInfo) : Platform.isIOS ? (await DeviceInfoPlugin().iosInfo) : (await DeviceInfoPlugin().deviceInfo);

      /// dynamischen Datenzustand von Server abfragen, mit Infos zu Plattform für aktuelle Versionsbestimmung
      final data = await (http.get(_ddUri("/data/status").replace(
        queryParameters: {
          "os": Platform.operatingSystem,
          "osver": (Platform.isAndroid ?
            "${(osVer as AndroidDeviceInfo).version.release} (API ${osVer.version.sdkInt})"
            : Platform.isIOS ? (osVer as IosDeviceInfo).systemVersion : "other"),
          "appver": pkg.version,
          "appvercode": pkg.buildNumber,
        },
      )).timeout(const Duration(seconds: 3)));
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
