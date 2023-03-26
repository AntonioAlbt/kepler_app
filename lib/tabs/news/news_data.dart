import 'package:enough_serialization/enough_serialization.dart';
import 'package:http/http.dart' as http;
import 'package:universal_feed/universal_feed.dart';

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
  final res = await http.get(Uri.parse(keplerNewsURL.replaceAll("{page}", "${page + 1}")));
  if (res.statusCode == 404) {
    return null;
  }
  final feed = Atom.parseFromString(res.body);
  if (feed.entries == null) return null;
  for (var e in feed.entries!) {
    final data = NewsEntryData()
      ..title = e.title ?? "???"
      ..createdDate = ((e.published != null) ? e.published!.parseValue() ?? DateTime(2023) : DateTime(2023))
      ..link = ((e.links?.isNotEmpty == true) ? e.links!.first.href : e.id) ?? "https://kepler-chemnitz.de"
      ..summary = e.summary ?? "..."
      ..writer = (e.authors?.isNotEmpty == true) ? e.authors!.first.name : null
      ..categories = (e.categories?.isNotEmpty == true) ? e.categories!.map((e) => e.term ?? "?").toList() : null;
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
