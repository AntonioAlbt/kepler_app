import 'dart:convert';
import 'dart:developer';

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:synchronized/synchronized.dart';
import 'package:universal_feed/universal_feed.dart';

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

const keplerNewsURL = "https://kepler-chemnitz.de/?feed=atom&paged={page}";

class NewsEntryData extends SerializableObject {
  NewsEntryData() {
    objectCreators["categories"] = (_) => <String>[];
  }

  String get title => attributes["title"];
  set title(String val) => attributes["title"] = val;

  String get summary => attributes["summary"];
  set summary(String val) => attributes["summary"] = val;

  String get link => attributes["link"];
  set link(String val) => attributes["link"] = val;

  DateTime get createdDate => DateTime.parse(attributes["created"]);
  set createdDate(DateTime val) =>
      attributes["created"] = val.toIso8601String();

  String? get writer => attributes["writer"];
  set writer(String? val) => attributes["writer"] = val;

  List<String>? get categories => attributes["categories"];
  set categories(List<String>? val) => attributes["categories"] = val;
}

Future<List<NewsEntryData>?> loadNews(int page) async {
  final newNewsData = <NewsEntryData>[];
  final http.Response res;
  try {
    res = await http.get(Uri.parse(keplerNewsURL.replaceAll("{page}", "${page + 1}")));
  } catch (_) {
    return null;
  }
  if (res.statusCode == 404) {
    return null;
  }
  final feed = UniversalFeed.parseFromString(res.body);
  if (feed.items.isEmpty) return null;
  for (var e in feed.items) {
    final data = NewsEntryData()
      ..title = e.title ?? "???"
      ..createdDate = ((e.published != null) ? e.published!.parseValue() ?? DateTime(2023) : DateTime(2023))
      ..link = ((e.links?.isNotEmpty == true) ? e.links.first.href : e.guid) ?? "https://kepler-chemnitz.de"
      ..summary = e.description ?? "..."
      ..writer = (e.authors?.isNotEmpty == true) ? e.authors.first.name : null
      ..categories = (e.categories?.isNotEmpty == true) ? e.categories.map((e) => e.term ?? "?").toList() : null;
    newNewsData.add(data);
  }
  return newNewsData;
}

Future<List<NewsEntryData>?> loadAllNewNews(String lastKnownNewsLink, [int maxCount = -1]) async {
  var page = 0;
  List<NewsEntryData>? latestNews = [];
  
  final newNews = <NewsEntryData>[];
  while (!latestNews!.any((element) => element.link == lastKnownNewsLink) && page < 50 && (newNews.length < maxCount || maxCount < 1)) {
    latestNews = await loadNews(page);
    if (latestNews == null || latestNews.isEmpty) return newNews;
    var count = 0;
    while (count < latestNews.length && latestNews[count].link != lastKnownNewsLink) {
      newNews.add(latestNews[count]);
      count++;
    }
    page++;
  }
  return newNews;
}
