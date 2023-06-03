import 'dart:convert';

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/tabs/news/news_data.dart';
import 'package:shared_preferences/shared_preferences.dart';


late final SharedPreferences sharedPreferences;

const newsCachePrefKey = "news_cache";
const credStorePrefKey = "cred_store";
const securePrefs = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);


final credentialStore = CredentialStore()
  ..lernSaxToken = ""
  ..vpUser = null
  ..vpPassword = null;
final newsCache = NewsCache()
  ..newsData = [];

class CredentialStore extends SerializableObject with ChangeNotifier {
  final _serializer = Serializer();
  bool loaded = false;
  save() async {
    await securePrefs.write(key: credStorePrefKey, value: _serialize());
  }

  String get lernSaxToken => attributes["lern_sax_token"];
  set lernSaxToken(String token) {
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

  List<NewsEntryData> get newsData => attributes["news_data"];
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

class AppState extends ChangeNotifier {
  /// needed to make current navigation available to the tabs, so they change content based on sub-tab
  List<int> selectedNavigationIndex = [0];

  InfoScreenDisplay? infoScreen;

  void setNavIndex(String newNavIndex) {
    selectedNavigationIndex = newNavIndex.split(".").map((e) => int.parse(e)).toList();
    notifyListeners();
  }

  void setInfoScreen(InfoScreenDisplay? newInfoScreen) {
    infoScreen = newInfoScreen;
    notifyListeners();
  }

  void clearInfoScreen() => setInfoScreen(null);
}

const internalStatePrefsKey = "internal_state";

final internalState = InternalState()
  ..introductionStep = 0;

class InternalState extends SerializableObject with ChangeNotifier {
  final _serializer = Serializer();

  int get introductionStep => attributes["introduction_step"];
  set introductionStep(int step) {
    attributes["introduction_step"] = step;
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
