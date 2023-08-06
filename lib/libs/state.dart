import 'dart:convert';

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/tabs/news/news_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final SharedPreferences sharedPreferences;

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

  String get lernSaxLogin => attributes["lern_sax_login"] ?? "";
  set lernSaxLogin(String login) {
    attributes["lern_sax_login"] = login;
    notifyListeners();
    save();
  }

  String? get lernSaxToken => attributes["lern_sax_token"];
  set lernSaxToken(String? token) {
    attributes["lern_sax_token"] = token;
    notifyListeners();
    save();
  }

  String? get vpUser => attributes["vp_user"];
  set vpUser(String? user) {
    attributes["vp_user"] = user;
    notifyListeners();
    save();
  }

  String? get vpPassword => attributes["vp_password"];
  set vpPassword(String? password) {
    attributes["vp_password"] = password;
    notifyListeners();
    save();
  }

  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    _serializer.deserialize(json, this);
    loaded = true;
  }
}

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
  save() async {
    sharedPreferences.setString(newsCachePrefKey, _serialize());
  }

  List<NewsEntryData> get newsData => attributes["news_data"] ?? [];
  set newsData(List<NewsEntryData> val) {
    attributes["news_data"] = val;
    notifyListeners();
    save();
  }

  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    _serializer.deserialize(json, this);
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
  List<int> selectedNavigationIndex = [0];

  InfoScreenDisplay? infoScreen;

  UserType userType = UserType.nobody;

  void setNavIndex(String newNavIndex) {
    selectedNavigationIndex =
        newNavIndex.split(".").map((e) => int.parse(e)).toList();
    notifyListeners();
  }

  void setInfoScreen(InfoScreenDisplay? newInfoScreen) {
    infoScreen = newInfoScreen;
    notifyListeners();
  }

  void clearInfoScreen() => setInfoScreen(null);

  void setUserType(UserType type) {
    userType = type;
    notifyListeners();
  }
}

const internalStatePrefsKey = "internal_state";

class InternalState extends SerializableObject with ChangeNotifier {
  final _serializer = Serializer();

  int get introductionStep => attributes["introduction_step"] ?? 0;
  set introductionStep(int step) {
    attributes["introduction_step"] = step;
    notifyListeners();
    save();
  }

  UserType? get lastUserType => attributes["last_user_type"];
  set lastUserType(UserType? type) {
    attributes["last_user_type"] = type;
    notifyListeners();
    save();
  }

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
Future<UserType> determineUserType(
    String? lernSaxLogin, String? vpUser, String? vpPassword) async {
  if (lernSaxLogin == null) return UserType.nobody;
  if (parentTypeEndings.any((element) => lernSaxLogin.endsWith(".$element"))) return UserType.parent;
  final lres = await authRequest(lUrlMKlXmlUrl, vpUser!, vpPassword!);
  if (lres.statusCode != 401) return UserType.teacher;
  final sres = await authRequest(sUrlMKlXmlUrl, vpUser, vpPassword);
  if (sres.statusCode != 401) return UserType.pupil;
  return UserType.nobody;
}
