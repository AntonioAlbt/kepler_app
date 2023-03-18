import 'dart:math';

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/news/news_view.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:kepler_app/tabs/news/news_data.dart';

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
  double opacity = 0;
  int lastNewsPage = 0;
  bool noMoreNews = false;
  bool loading = false;

  late final AutoScrollController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: newsCache,
      builder: (context, _) {
        final loadedNews = newsCache.newsData.map((d) => NewsEntry(data: d)).toList();
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
                                    newsCache.newsData.clear();
                                    setState(() {
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
    );
  }

  Future _loadMoreNews() async {
    if (noMoreNews || loading) return;
    if (lastNewsPage > 50) {
      setState(() {
        noMoreNews = true;
      });
      return;
    }
    setState(() {
      loading = true;
    });

    final newNewsData = await loadNews(lastNewsPage);

    if (newNewsData == null) {
      setState(() {
        noMoreNews = true;
        loading = false;
      });
    } else {
      newNewsData.removeWhere((e1) => newsCache.newsData.any((e2) => e1.link == e2.link));
      while (newNewsData.length < 9 && lastNewsPage < 50) {
        lastNewsPage++;
        final moreData = await loadNews(lastNewsPage);
        if (moreData == null || moreData.isEmpty) break;
        newNewsData.addAll(moreData);
      }
      newsCache.addNewsData(newNewsData);
      lastNewsPage++;
      setState(() {
        loading = false;
      });
    }
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
