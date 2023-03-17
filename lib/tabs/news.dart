import 'dart:developer' as dev;
import 'dart:math';

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:dart_rss/dart_rss.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/tabs/news_view.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:http/http.dart' as http;

const keplerNewsURL = "https://kepler-chemnitz.de/?feed=atom&paged={page}";

extension StringExtension on String {
  String truncateTo(int maxLength) =>
      (length <= maxLength) ? this : '${substring(0, maxLength)}...';
  
  String stripHtmlIfNeeded() => replaceAll(RegExp(r"<[^>]*>|&[^;]+;"), " ");
}

class NewsTab extends StatefulWidget {
  const NewsTab({super.key});

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class NewsEntryData extends SerializableObject {
  String get title => attributes["title"];
  set title(String val) => attributes["title"] = val;

  String get summary => attributes["summary"];
  set summary(String val) => attributes["summary"] = val;

  String get link => attributes["link"];
  set link(String val) => attributes["link"] = val;

  DateTime get createdDate => DateTime.parse(attributes["created"]);
  set createdDate(DateTime val) => attributes["created"] = val.toIso8601String();

  String? get writer => attributes["writer"];
  set writer(String? val) => attributes["writer"] = val;
}

class NewsEntry extends StatelessWidget with SerializableObject {
  final NewsEntryData data;
  late final Color color;

  NewsEntry({super.key, required this.data}) {
    final random = Random(data.link.hashCode);
    color = HSLColor.fromAHSL(1, random.nextDouble() * 360, random.nextDouble(), 0.9).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: ListTile(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: DateFormat.yMMMMd().format(data.createdDate),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    ),
                    TextSpan(
                      text: "  -  verfasst von ${data.writer}",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600
                      ),
                    )
                  ]
                ),
              ),
              Text(
                HtmlUnescape().convert(data.title),
              ),
            ],
          ),
          subtitle: Text(
            HtmlUnescape().convert(data.summary.stripHtmlIfNeeded()),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
            textAlign: TextAlign.justify,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NewsView(
                  newsLink: Uri.parse(data.link),
                  newsTitle: data.title,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NewsTabState extends State<NewsTab> {
  List<NewsEntry> loadedNews = [];
  double opacity = 0;
  int lastNewsPage = 0;
  bool noMoreNews = false;
  bool loading = false;

  late final AutoScrollController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: (loadedNews.isEmpty) ?
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: CircularProgressIndicator(),
              ),
              Text("News werden geladen...")
            ],
          ),
        )
        :
        LazyLoadScrollView(
          onEndOfPage: () => _loadMoreNews(),
          child: Scrollbar(
            controller: controller,
            radius: const Radius.circular(4),
            thickness: 4.75,
            child: ListView.builder(
              itemCount: loadedNews.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8),
                    child: ListTile(
                      title: Transform.translate(
                        offset: const Offset(0, 5),
                        child: Column(
                          children: [
                            const Text(
                              "Tippe auf die Nachrichten, um sie anzusehen.",
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: 14
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  loadedNews.clear();
                                  noMoreNews = false;
                                  lastNewsPage = 0;
                                });
                                _loadMoreNews();
                              },
                              child: Text(
                                "News neu laden",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                }
                if (index == loadedNews.length + 1) {
                  if (noMoreNews) {
                    return const ListTile(
                      title: Text("Keine weiteren News."),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: CircularProgressIndicator(),
                      title: Text("Lädt mehr News..."),
                    ),
                  );
                }
                return AutoScrollTag(
                  key: ValueKey(index),
                  index: index,
                  controller: controller,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: loadedNews[index - 1],
                  ),
                );
              },
              controller: controller,
            ),
          ),
        ),
      floatingActionButton: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 100),
        child: FloatingActionButton(
          onPressed: () => controller.scrollToIndex(0),
          child: const Icon(Icons.arrow_upward),
        )
      ),
    );
  }

  Future _loadMoreNews() async {
    if (noMoreNews || loading) return;
    setState(() {
      loading = true;
    });
    final newNews = <NewsEntry>[];
    final res = await http.get(Uri.parse(keplerNewsURL.replaceAll("{page}", "${lastNewsPage + 1}")));
    if (res.statusCode == 404) {
      setState(() {
        noMoreNews = true;
      });
      return;
    }
    final feed = AtomFeed.parse(res.body);
    for (var e in feed.items) {
      final entry = NewsEntry(
        data: NewsEntryData()
          ..title = e.title ?? "???"
          ..createdDate = ((e.published != null) ? DateTime.parse(e.published!) : DateTime(2023))
          ..link = ((e.links.isNotEmpty) ? e.links.first.href : e.id) ?? "https://kepler-chemnitz.de"
          ..summary = e.summary ?? "..."
          ..writer = (e.authors.isNotEmpty) ? e.authors.first.name : null
      );
      newNews.add(
        entry
      );
    }
    lastNewsPage++;
    setState(() {
      if (loadedNews.any((element1) => newNews.any((element2) => element1.data.title == element2.data.title))) dev.log("loaded news which is alr existing.... :(");
      loadedNews.addAll(newNews);
      loading = false;
    });
  }

  @override
  void initState() {
    controller = AutoScrollController();
    super.initState();
    _loadMoreNews();
    controller.addListener(() {
      setState(() => opacity = (controller.hasClients && controller.offset >= 300) ? 1 : 0);
    }); // update opacity depending on scroll position
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
