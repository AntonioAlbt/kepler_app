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

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/indiware.dart' as indiware show baseUrl;
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final SharedPreferences sharedPreferences;
bool hasDarkTheme(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

const newsCachePrefKey = "news_cache";
const credStorePrefKey = "cred_store";
const securePrefs = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

const lernSaxDemoModeMail = "jkgappdemo@jkgc.lernsax.de";

class CredentialStore extends SerializableObject with ChangeNotifier {
  CredentialStore() {
    objectCreators["alt_ls_logins"] = (_) => <String>[];
    objectCreators["alt_ls_tokens"] = (_) => <String>[];
  }

  final _serializer = Serializer();
  bool loaded = false;
  Future<void> save() async {
    await securePrefs.write(key: credStorePrefKey, value: _serialize());
  }

  void _setSaveNotify(String key, dynamic data) {
    attributes[key] = data;
    notifyListeners();
    save();
  }

  String? get lernSaxLogin => attributes["lern_sax_login"] ?? "";
  set lernSaxLogin(String? login) {
    if (kCredsDebug) logCatch("creds-debug", "lernSaxLogin changed to ${login == null ? "null" : "value with len ${login.length}"}", StackTrace.current);
    _setSaveNotify("lern_sax_login", login);
  }

  String? get lernSaxToken => attributes["lern_sax_token"];
  set lernSaxToken(String? token) {
    if (kCredsDebug) logCatch("creds-debug", "lernSaxToken changed to ${token == null ? "null" : "value with len ${token.length}"}", StackTrace.current);
    _setSaveNotify("lern_sax_token", token);
  }

  List<String> get alternativeLSLogins => attributes["alt_ls_logins"] ?? ["a.a"];
  set alternativeLSLogins(List<String> list) {
    _setSaveNotify("alt_ls_logins", list);
  }

  List<String> get alternativeLSTokens => attributes["alt_ls_tokens"] ?? [];
  set alternativeLSTokens(List<String> list) {
    _setSaveNotify("alt_ls_tokens", list);
  }
  
  void addAlternativeLSUser(String login, String token) {
    alternativeLSLogins = alternativeLSLogins..add(login);
    alternativeLSTokens = alternativeLSTokens..add(token);
  }

  String? get vpHost => attributes["vp_host"] ?? indiware.baseUrl;
  set vpHost(String? host) => _setSaveNotify("vp_host", host);

  String? get vpUser => attributes["vp_user"];
  set vpUser(String? user) {
    if (kCredsDebug) logCatch("creds-debug", "vpUser changed to ${user == null ? "null" : "value with len ${user.length}"}", StackTrace.current);
    _setSaveNotify("vp_user", user);
  }

  String? get vpPassword => attributes["vp_password"];
  set vpPassword(String? password) {
    if (kCredsDebug) logCatch("creds-debug", "vpPassword changed to ${password == null ? "null" : "value with len ${password.length}"}", StackTrace.current);
    _setSaveNotify("vp_password", password);
  }

  // VP doesn't need alternative accounts, because it's the same

  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    _serializer.deserialize(json, this);
    loaded = true;
  }

  void clearData() {
    lernSaxLogin = null;
    lernSaxToken = null;
    vpHost = null;
    vpUser = null;
    vpPassword = null;
  }
}

enum UserType {
  pupil, teacher, parent, nobody;
  @override
  String toString() {
    return {
      UserType.pupil: "Schüler",
      UserType.teacher: "Lehrer",
      UserType.parent: "Elternteil",
      UserType.nobody: "nicht angemeldet",
    }[this]!;
  }
}

class AppState extends ChangeNotifier {
  /// needed to make current navigation available to the tabs, so they change content based on sub-tab
  /// last ID is for "topmost" (currently visible) page
  List<String> _selectedNavPageIDs = [PageIDs.home];
  List<String> get selectedNavPageIDs => _selectedNavPageIDs;
  set selectedNavPageIDs(List<String> newSNPID) {
    _selectedNavPageIDs = newSNPID;
    notifyListeners();
  }

  List<String>? navPagesToOpenAfterNextISClose;

  InfoScreenDisplay? _infoScreen;
  InfoScreenDisplay? get infoScreen => _infoScreen;
  set infoScreen(InfoScreenDisplay? isd) {
    _infoScreen = isd;
    if (isd == null && navPagesToOpenAfterNextISClose != null) {
      selectedNavPageIDs = navPagesToOpenAfterNextISClose!;
      navPagesToOpenAfterNextISClose = null;
    }
    notifyListeners();
  }

  UserType _userType = UserType.nobody;
  UserType get userType => _userType;
  set userType(UserType ut) {
    _userType = ut;
    notifyListeners();
  }

  void clearInfoScreen() => infoScreen = null;
}

const internalStatePrefsKey = "internal_state";

class InternalState extends SerializableObject with ChangeNotifier {
  final _serializer = Serializer();

  void _setSaveNotify(String key, dynamic data) {
    attributes[key] = data;
    notifyListeners();
    save();
  }

  UserType? get lastUserType => UserType.values.firstWhere((element) => element.name == attributes["last_user_type"], orElse: () => UserType.nobody);
  set lastUserType(UserType? type) => _setSaveNotify("last_user_type", type?.name);

  DateTime? get lastUserTypeCheck => (attributes.containsKey("last_ut_check") && attributes["last_ut_check"] != null) ? DateTime.parse(attributes["last_ut_check"]) : null;
  set lastUserTypeCheck(DateTime? val) => _setSaveNotify("last_ut_check", val?.toIso8601String());

  bool get introShown => attributes["intro_shown"] ?? false;
  set introShown(bool introShown) => _setSaveNotify("intro_shown", introShown);

  String? get lastSelectedClassPlan => attributes["lscp"];
  set lastSelectedClassPlan(String? val) => _setSaveNotify("lscp", val);
  String? get lastSelectedRoomPlan => attributes["lsrp"];
  set lastSelectedRoomPlan(String? val) => _setSaveNotify("lsrp", val);
  String? get lastSelectedTeacherPlan => attributes["lstp"];
  set lastSelectedTeacherPlan(String? val) => _setSaveNotify("lstp", val);
  String? get lastSelectedLSTaskClass => attributes["lslstc"];
  set lastSelectedLSTaskClass(String? val) => _setSaveNotify("lslstc", val);
  bool get lastSelectedLSTaskShowDone => attributes["lslstsd"] ?? false;
  set lastSelectedLSTaskShowDone(bool val) => _setSaveNotify("lslstsd", val);
  String? get lastSelectedLSMailFolder => attributes["lslsmf"];
  set lastSelectedLSMailFolder(String? val) => _setSaveNotify("lslsmf", val);

  List<String> get infosShown => (attributes["infos_shown"] as String?)?.split("|") ?? [];
  set infosShown(List<String> val) => _setSaveNotify("infos_shown", val.join("|"));
  void addInfoShown(String info) => infosShown = infosShown..add(info);

  List<String> get widgetsAdded => (attributes["widgets_added"] as String?)?.split("|") ?? [];
  set widgetsAdded(List<String> val) => _setSaveNotify("widgets_added", val.join("|"));

  DateTime? get lastStuPlanAutoReload => (attributes.containsKey("last_sp_auto_rl") && attributes["last_sp_auto_rl"] != null) ? DateTime.parse(attributes["last_sp_auto_rl"]) : null;
  set lastStuPlanAutoReload(DateTime? val) => _setSaveNotify("last_sp_auto_rl", val?.toIso8601String());

  int get lastChangelogShown => attributes["last_cl_shown"] ?? -1;
  set lastChangelogShown(int val) => _setSaveNotify("last_cl_shown", val);

  bool loaded = false;

  Future<void> save() async {
    sharedPreferences.setString(internalStatePrefsKey, _serialize());
  }

  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    _serializer.deserialize(json, this);
    loaded = true;
  }
}

final parentTypeEndings = [
  "eltern",
  "vati",
  "mutti",
  "grosseltern",
  "tante",
  "onkel"
];

/// This function assumes that the lernsax login is valid and the user has an internet connection.
Future<UserType> determineUserType(String? lernSaxLogin, String? lernSaxToken) async {
  if (lernSaxLogin == null || lernSaxToken == null) return UserType.nobody;
  if (parentTypeEndings.any((element) => lernSaxLogin.split("@")[0].endsWith(".$element"))) return UserType.parent;
  final (online, teach) = await isTeacher(lernSaxLogin, lernSaxToken);
  if (!online) return UserType.nobody;
  if (teach == true) return UserType.teacher;
  if (teach == false) return UserType.pupil;
  return UserType.nobody;
}
