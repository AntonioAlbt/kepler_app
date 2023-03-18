import 'package:dart_rss/dart_rss.dart';
import 'package:enough_serialization/enough_serialization.dart';
import 'package:http/http.dart' as http;

const keplerNewsURL = "https://kepler-chemnitz.de/?feed=atom&paged={page}";

class NewsEntryData extends SerializableObject {
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
}

Future<List<NewsEntryData>?> loadNews(int page) async {
  final newNewsData = <NewsEntryData>[];
  final res = await http.get(Uri.parse(keplerNewsURL.replaceAll("{page}", "${page + 1}")));
  if (res.statusCode == 404) {
    return null;
  }
  final feed = AtomFeed.parse(res.body);
  for (var e in feed.items) {
    final data = NewsEntryData()
      ..title = e.title ?? "???"
      ..createdDate = ((e.published != null) ? DateTime.parse(e.published!) : DateTime(2023))
      ..link = ((e.links.isNotEmpty) ? e.links.first.href : e.id) ?? "https://kepler-chemnitz.de"
      ..summary = e.summary ?? "..."
      ..writer = (e.authors.isNotEmpty) ? e.authors.first.name : null;
    newNewsData.add(
      data
    );
  }
  return newNewsData;
}
