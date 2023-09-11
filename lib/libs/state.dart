import 'dart:convert';
import 'dart:developer';

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/indiware.dart';
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
  save() async {
    await securePrefs.write(key: credStorePrefKey, value: _serialize());
  }

  void _setSaveNotify(String key, dynamic data) {
    attributes[key] = data;
    notifyListeners();
    save();
  }

  String get lernSaxLogin => attributes["lern_sax_login"] ?? "";
  set lernSaxLogin(String login) => _setSaveNotify("lern_sax_login", login);

  String? get lernSaxToken => attributes["lern_sax_token"];
  set lernSaxToken(String? token) => _setSaveNotify("lern_sax_token", token);

  String? get vpUser => attributes["vp_user"];
  set vpUser(String? user) => _setSaveNotify("vp_user", user);

  String? get vpPassword => attributes["vp_password"];
  set vpPassword(String? password) => _setSaveNotify("vp_password", password);

  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    _serializer.deserialize(json, this);
    loaded = true;
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
      Sentry.captureException(e, stackTrace: s);
      return;
    }
    loaded = true;
  }

  NewsEntryData? getCachedNewsData(String link) {
    return newsData.firstWhere((element) => element.link == link);
  }

  void addNewsData(List<NewsEntryData> data) {
    final oldData = newsData;
    oldData.addAll(data);
    newsData = oldData;
  }

  void insertNewsData(int index, List<NewsEntryData> data) {
    final oldData = newsData;
    oldData.insertAll(index, data);
    newsData = oldData;
  }
}

enum UserType { pupil, teacher, parent, nobody }

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

  bool get introShown => attributes["intro_shown"] ?? false;
  set introShown(bool introShown) => _setSaveNotify("intro_shown", introShown);

  String? get lastSelectedClassPlan => attributes["lscp"];
  set lastSelectedClassPlan(String? val) => _setSaveNotify("lscp", val);
  String? get lastSelectedRoomPlan => attributes["lsrp"];
  set lastSelectedRoomPlan(String? val) => _setSaveNotify("lsrp", val);
  String? get lastSelectedTeacherPlan => attributes["lstp"];
  set lastSelectedTeacherPlan(String? val) => _setSaveNotify("lstp", val);

  bool loaded = false;

  save() async {
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

/// This function assumes that the provided logins are valid and were checked beforehand and that the user has an internet connection.
Future<UserType> determineUserType(String? lernSaxLogin, String? vpUser, String? vpPassword) async {
  if (lernSaxLogin == null) return UserType.nobody;
  if (parentTypeEndings.any((element) => lernSaxLogin.split("@")[0].endsWith(".$element"))) return UserType.parent;
  final lres = await authRequest(lUrlMLeXmlUrl, vpUser!, vpPassword!);
  if (lres!.statusCode != 401) return UserType.teacher;
  final sres = await authRequest(sUrlMKlXmlUrl, vpUser, vpPassword);
  if (sres!.statusCode != 401) return UserType.pupil;
  return UserType.nobody;
}
