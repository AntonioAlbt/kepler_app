import 'dart:convert';
import 'dart:developer';

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/indiware.dart' as indiware show baseUrl;
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/news/news_data.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

late final SharedPreferences sharedPreferences;
bool hasDarkTheme(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

const newsCachePrefKey = "news_cache";
const credStorePrefKey = "cred_store";
const securePrefs = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class CredentialStore extends SerializableObject with ChangeNotifier {
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
  set lernSaxLogin(String? login) => _setSaveNotify("lern_sax_login", login);

  String? get lernSaxToken => attributes["lern_sax_token"];
  set lernSaxToken(String? token) => _setSaveNotify("lern_sax_token", token);

  String? get vpHost => attributes["vp_host"] ?? indiware.baseUrl;
  set vpHost(String? host) => _setSaveNotify("vp_host", host);

  String? get vpUser => attributes["vp_user"];
  set vpUser(String? user) => _setSaveNotify("vp_user", user);

  String? get vpPassword => attributes["vp_password"];
  set vpPassword(String? password) => _setSaveNotify("vp_password", password);

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

Future<String> get newsCacheDataFilePath async => "${await cacheDirPath}/$newsCachePrefKey-data.json";
class NewsCache extends SerializableObject with ChangeNotifier {
  NewsCache() {
    objectCreators["news_data"] = (map) => <NewsEntryData>[];
    objectCreators["news_data.value"] = (val) {
      final obj = NewsEntryData();
      _serializer.deserialize(jsonEncode(val), obj);
      return obj;
    };
  }

  final _serializer = Serializer();
  bool loaded = false;
  final Lock _fileLock = Lock();
  Future<void> save() async {
    if (_fileLock.locked) log("The file lock for NewsCache (file: cache/$newsCachePrefKey-data.json) is still locked!!! This means waiting...");
    _fileLock.synchronized(() async => await writeFile(await newsCacheDataFilePath, _serialize()));
  }

  void _setSaveNotify(String key, dynamic data) {
    attributes[key] = data;
    notifyListeners();
    save();
  }

  List<NewsEntryData> get newsData => attributes["news_data"] ?? [];
  set newsData(List<NewsEntryData> val) => _setSaveNotify("news_data", val);

  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    try {
      _serializer.deserialize(json, this);
    } catch (e, s) {
      log("Error while decoding json for NewsCache from file:", error: e, stackTrace: s);
      if (globalSentryEnabled) Sentry.captureException(e, stackTrace: s);
      return;
    }
    loaded = true;
  }

  NewsEntryData? getCachedNewsData(String link) {
    return newsData.firstWhere((element) => element.link == link);
  }

  void addNewsData(List<NewsEntryData> data, {bool sort = true}) {
    final oldData = newsData;
    oldData.addAll(data);
    if (sort) {
      newsData = oldData..sort((a, b) => b.createdDate.compareTo(a.createdDate));
    } else {
      newsData = oldData;
    }
  }

  void insertNewsData(int index, List<NewsEntryData> data, {bool sort = true}) {
    final oldData = newsData;
    oldData.insertAll(index, data);
    if (sort) {
      newsData = oldData..sort((a, b) => b.createdDate.compareTo(a.createdDate));
    } else {
      newsData = oldData;
    }
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

  InfoScreenDisplay? _infoScreen;
  InfoScreenDisplay? get infoScreen => _infoScreen;
  set infoScreen(InfoScreenDisplay? isd) {
    _infoScreen = isd;
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

  String? get nowOpenOnStartup => attributes["open_on_startup"];
  set nowOpenOnStartup(String? val) => _setSaveNotify("open_on_startup", val);

  DateTime? get lastStuPlanAutoReload => (attributes.containsKey("last_sp_auto_rl") && attributes["last_sp_auto_rl"] != null) ? DateTime.parse(attributes["last_sp_auto_rl"]) : null;
  set lastStuPlanAutoReload(DateTime? val) => _setSaveNotify("last_sp_auto_rl", val?.toIso8601String());

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
