import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/tabs/news.dart';

final credentialStore = CredentialStore();
final newsCache = NewsCache();

class CredentialStore extends SerializableObject {
  final _serializer = Serializer();
  bool loaded = false;

  String get lernSaxToken => attributes["lern_sax_token"];
  set lernSaxToken(String token) => attributes["lern_sax_token"] = token;

  String serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    _serializer.deserialize(json, this);
    loaded = true;
  }
}

class NewsCache extends SerializableObject {
  NewsCache() {
    objectCreators["news_data"] = (map) => <NewsEntryData>[];
  }

  final _serializer = Serializer();
  bool loaded = false;

  List<NewsEntryData> get newsData => attributes["news_data"];
  set newsData(List<NewsEntryData> val) => attributes["news_data"] = val;

  String serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    _serializer.deserialize(json, this);
    loaded = true;
  }

  NewsEntryData? getCachedNewsData(String link) {
     return newsData.firstWhere((element) => element.link == link);
  }
}

class AppState extends ChangeNotifier {
  /// needed to make current navigation available to the tabs, so they change content based on sub-tab
  List<int> selectedNavigationIndex = [];

  void setNavIndex(String newNavIndex) {
    selectedNavigationIndex = newNavIndex.split(".").map((e) => int.parse(e)).toList();
    notifyListeners();
  }
}
