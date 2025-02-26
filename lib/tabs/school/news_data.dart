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

import 'dart:convert';
import 'dart:developer';

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:rss_dart/dart_rss.dart';
import 'package:synchronized/synchronized.dart';

const keplerNewsURL = "https://kepler-chemnitz.de/?feed=atom&paged={page}";
const keplerEvtApiURL = "https://www.kepler-chemnitz.de/wp-json/tribe/events/v1";

// the news data sometimes has these in it - so I'm just replacing them when loading
/// Dart scheitert beim Laden von solchen Zeichen - aber nicht beim Speichern?
/// naja, durch das Entfernen vorm Speichern wird nicht jedes Mal beim Laden der Cache gelöscht
final List<String> controlCharacters = (){
  final out = <String>[];
  for (var i = 0; i < 32; i++) {
    out.add(String.fromCharCode(i));
  }
  return out;
}();

/// Speicherpfad des NewsCaches, wird separat gespeichert, da er relativ groß werden kann
Future<String> get newsCacheDataFilePath async => "${await cacheDirPath}/$newsCachePrefKey-data.json";

/// Cache für abgefragte Kepler-News-RSS-Einträge und Kalender-Events
class NewsCache extends SerializableObject with ChangeNotifier {
  NewsCache() {
    objectCreators["news_data"] = (map) => <NewsEntryData>[];
    objectCreators["news_data.value"] = (val) {
      final obj = NewsEntryData();
      _serializer.deserialize(jsonEncode(val), obj);
      return obj;
    };

    objectCreators["evt_data"] = (map) => <CalendarEntryData>[];
    objectCreators["evt_data.value"] = (val) {
      final obj = CalendarEntryData.empty();
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

  List<CalendarEntryData> get calData => attributes["evt_data"] ?? [];
  set calData(List<CalendarEntryData> val) => _setSaveNotify("evt_data", val);

  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    try {
      String finalJson = json;
      for (var char in controlCharacters) {
        finalJson = finalJson.replaceAll(char, "");
      }
      _serializer.deserialize(finalJson, this);
    } catch (e, s) {
      log("Error while decoding json for NewsCache from file:", error: e, stackTrace: s);
      logCatch("news_data", e, s);
      return;
    }
    loaded = true;
  }

  NewsEntryData? getCachedNewsData(String link) {
    return newsData.firstWhere((element) => element.link == link);
  }

  List<CalendarEntryData> getCalEntryDataForDay(DateTime day) {
    return calData.where((data) {
      return data.startDate != null && _isSameDay(data.startDate!, day);
    }).toList();
  }

  void addNewsData(List<NewsEntryData> data, {bool sort = true}) {
    final oldData = newsData;
    oldData.addAll(data.where((news) => !oldData.map((e) => e.link).contains(news.link)));
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

  void replaceMonthInCalData(DateTime month, List<CalendarEntryData> data, {bool sort = true}) {
    final old = calData.where((element) => element.startDate == null || !_isSameMonth(element.startDate!, month)).toList();
    // only add new entries where startDate is defined and is in the requested month
    old.addAll(data.where((element) => element.startDate != null && _isSameMonth(element.startDate!, month)));
    if (sort) old.sort((a, b) => b.startDate != null ? (a.startDate?.compareTo(b.startDate!) ?? 0) : 0);
    calData = old;
  }

  void clearData() {
    newsData = [];
    calData = [];
  }
}

bool _isSameMonth(DateTime one, DateTime two) => one.year == two.year && one.month == two.month;
bool _isSameDay(DateTime one, DateTime two) => _isSameMonth(one, two) && one.day == two.day;

/// Kepler-News-RSS-Eintrag mit allen wichtigen Metadaten
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

/// lädt News von RSS-Feed auf Seite 2 laut Wordpress
Future<List<NewsEntryData>?> loadNews(int page) async {
  final newNewsData = <NewsEntryData>[];
  final http.Response res;
  try {
    res = await http.get(Uri.parse(keplerNewsURL.replaceAll("{page}", "${page + 1}")));
  } catch (e, s) {
    logCatch("news-data", e, s);
    return null;
  }
  if (res.statusCode == 404) {
    return null;
  }
  final feed = AtomFeed.parse(res.body);
  if (feed.items.isEmpty) return null;
  for (var e in feed.items) {
    final data = NewsEntryData()
      ..title = e.title ?? "???"
      ..createdDate = ((e.published != null) ? DateTime.parse(e.published ?? DateTime(2023).toIso8601String()) : DateTime(2023))
      ..link = ((e.links?.isNotEmpty == true) ? e.links.first.href : e.id) ?? "https://kepler-chemnitz.de"
      ..summary = e.summary ?? "..."
      ..writer = (e.authors?.isNotEmpty == true) ? e.authors.first.name : null
      ..categories = (e.categories?.isNotEmpty == true) ? e.categories.map((e) => e.term ?? "?").toList() : null;
    newNewsData.add(data);
  }
  return newNewsData;
}

/// lädt alle News, die nach lastKnownNewsLink hinzugefügt wurden (lädt so lange News, bis lastKnownNewsLink
/// erreicht wird oder maxCount Nachrichten geladen wurden)
Future<List<NewsEntryData>?> loadAllNewNews(String lastKnownNewsLink, [int maxCount = 1000]) async {
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

/// Kalender-Eintrag, Metadaten laut WP-Events-Plugin-API
class CalendarEntryData extends SerializableObject {
  String get title => attributes["title"];
  set title(String val) => attributes["title"] = val;

  /// may contain HTML!
  String get description => attributes["description"];
  set description(String val) => attributes["description"] = val;

  String get link => attributes["link"];
  set link(String val) => attributes["link"] = val;

  DateTime? get startDate => attributes.containsKey("start_date") && attributes["start_date"] != null ? DateTime.parse(attributes["start_date"]) : null;
  set startDate(DateTime? val) => attributes["start_date"] = val?.toIso8601String();

  DateTime? get endDate => attributes.containsKey("end_date") && attributes["end_date"] != null ? DateTime.parse(attributes["end_date"]) : null;
  set endDate(DateTime? val) => attributes["end_date"] = val?.toIso8601String();

  String? get venueName => attributes["venue_name"];
  set venueName(String? val) => attributes["venue_name"] = val;

  String? get organizerName => attributes["organizer_name"];
  set organizerName(String? val) => attributes["organizer_name"] = val;

  CalendarEntryData({
    required String title,
    required String description,
    required String link,
    required DateTime? startDate,
    required DateTime? endDate,
    required String? venueName,
    required String? organizerName,
  }) {
    this.title = title;
    this.description = description;
    this.link = link;
    this.startDate = startDate;
    this.endDate = endDate;
    this.venueName = venueName;
    this.organizerName = organizerName;
  }

  CalendarEntryData.empty();
}

final calApiDateFormat = DateFormat("yyyy-MM-dd");
/// lädt Kalendereinträge für Monat, in dem Datum `month` liegt
Future<(bool, List<CalendarEntryData>?)> loadCalendarEntries(DateTime month) async {
  final startDate = DateTime(month.year, month.month, 1);
  final endDate = DateTime(month.year, month.month + 1, 1).subtract(const Duration(days: 1));
  final http.Response res;
  try {
    res = await http.get(Uri.parse("$keplerEvtApiURL/events?start_date=${calApiDateFormat.format(startDate)}&end_date=${calApiDateFormat.format(endDate)}"));
  } catch (e, s) {
    logCatch("news-data", e, s);
    return (false, null);
  }

  try {
    final out = <CalendarEntryData>[];
    for (final evtData in ((jsonDecode(res.body) as Map<String, dynamic>)["events"] as List<dynamic>).cast<Map<String, dynamic>>()) {
      final venueData = evtData["venue"]; // can be null, List or Map
      out.add(CalendarEntryData(
        title: evtData["title"],
        description: evtData["description"],
        link: evtData["url"],
        organizerName: ((evtData["organizer"] as List<dynamic>).firstOrNull as Map<String, dynamic>?)?["organizer"],
        venueName: (venueData is Map ? venueData["venue"] : null),
        startDate: evtData.containsKey("start_date") ? DateTime.parse(evtData["start_date"]) : null,
        endDate: evtData.containsKey("end_date") ? DateTime.parse(evtData["end_date"]) : null,
      ));
    }
    logDebug("cal-data", "loaded ${out.length} events from ${res.request?.url.toString()}");
    return (true, out);
  } catch (e, s) {
    logCatch("cal-data", e, s);
    log("", error: e, stackTrace: s);
    return (true, null);
  }
}
