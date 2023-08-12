import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/news/news_view.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:kepler_app/tabs/news/news_data.dart';
import 'package:provider/provider.dart';

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

class _NewsTabState extends State<NewsTab> {
  double opacity = 0;
  int lastNewsPage = 0;
  bool noMoreNews = false;
  bool loading = false;

  late final ScrollController _controller;
  late final NewsCache _newsCache;

  Future _resetNews() {
    _newsCache.newsData.clear();
    setState(() {
      noMoreNews = false;
      lastNewsPage = 0;
    });
    return _loadMoreNews();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<NewsCache, Preferences>(
      builder: (context, newsCache, prefs, _) {
        final loadedNews = newsCache.newsData.asMap().map((i, d) => MapEntry(i, NewsEntry(data: d, count: i, prefs: prefs,))).values.toList()
          ..sort((a, b) => b.data.createdDate.compareTo(a.data.createdDate));
        return Scaffold(
          body: LazyLoadScrollView(
            onEndOfPage: () => _loadMoreNews(),
            child: Scrollbar(
              controller: _controller,
              radius: const Radius.circular(4),
              thickness: 4.75,
              child: RefreshIndicator(
                onRefresh: () async { _resetNews(); },
                child: ListView.builder(
                  itemCount: loadedNews.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        title: Transform.translate(
                          offset: const Offset(0, 5),
                          child: const Text(
                            "Nachrichten antippen, um sie anzusehen.",
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 15
                            ),
                          ),
                        ),
                        visualDensity: const VisualDensity(vertical: -4),
                      );
                    }
                    if (index == loadedNews.length + 1) {
                      if (noMoreNews) {
                        return const ListTile(
                          title: Text("Keine weiteren News."),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListTile(
                          leading: const CircularProgressIndicator(),
                          title: Text("Lädt${(loadedNews.isNotEmpty) ? " mehr" : ""} News..."),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: loadedNews[index - 1],
                    );
                  },
                  controller: _controller,
                ),
              ),
            ),
          ),
          floatingActionButton: AnimatedOpacity(
            opacity: opacity,
            duration: const Duration(milliseconds: 100),
            child: FloatingActionButton(
              onPressed: () => _controller.animateTo(1, duration: const Duration(milliseconds: 1000), curve: Curves.decelerate),
              child: const Icon(Icons.arrow_upward),
            )
          ),
        );
      }
    );
  }

  Future _loadMoreNews() async {
    if (noMoreNews || loading) return;
    if (_newsCache.newsData.isNotEmpty) {
      final newStartNews = await loadAllNewNews(_newsCache.newsData.first.link);
      if (newStartNews != null) _newsCache.insertNewsData(0, newStartNews);
    }
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
      newNewsData.removeWhere((e1) => _newsCache.newsData.any((e2) => e1.link == e2.link));
      while (newNewsData.length < 9 && lastNewsPage < 50) {
        lastNewsPage++;
        final moreData = await loadNews(lastNewsPage);
        if (moreData == null || moreData.isEmpty) break;
        newNewsData.addAll(moreData);
      }
      _newsCache.addNewsData(newNewsData);
      lastNewsPage++;
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _newsCache = Provider.of<NewsCache>(context, listen: false);
    if (!_newsCache.loaded || _newsCache.newsData.isEmpty) _loadMoreNews();
    _controller.addListener(() {
      setState(() => opacity = (_controller.hasClients && _controller.offset >= 600) ? 1 : 0);
    }); // update opacity depending on scroll position
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final _colors = [keplerColorOrange, keplerColorYellow];
  Color getNEntryCol(int count, bool darkMode) {
    return HSLColor.fromColor(_colors[count % _colors.length])
        .withLightness((darkMode) ? .2 : .8)
        .withSaturation((darkMode) ? .3 : .7)
        .toColor();
  }
}

class NewsEntry extends StatelessWidget with SerializableObject {
  final NewsEntryData data;
  final int count;
  final Preferences prefs;
  late final Color color;

  NewsEntry({super.key, required this.data, this.count = 0, required this.prefs}) {
    final colors = [keplerColorOrange, keplerColorYellow];
    color = HSLColor.fromColor(colors[count % colors.length]).withLightness((prefs.darkTheme) ? .2 : .8).withSaturation((prefs.darkTheme) ? .3 : .7).toColor();
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
                    WidgetSpan(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Transform.translate(
                          offset: const Offset(0, -2),
                          child: Icon(MdiIcons.calendar,
                              size: 12, color: Colors.grey[(prefs.darkTheme) ? 300 : 700]),
                        ),
                      ),
                    ),
                    TextSpan(
                      text: DateFormat.yMMMMd().format(data.createdDate),
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[(prefs.darkTheme) ? 200 : 800]),
                    ),
                  ],
                ),
              ),
              Text(
                HtmlUnescape().convert(data.title),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodyMedium!,
                  child: Text(
                    HtmlUnescape().convert(data.summary.stripHtmlIfNeeded()),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                    textAlign: TextAlign.justify,
                  ),
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    WidgetSpan(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Transform.translate(
                          offset: const Offset(0, -2),
                          child: Icon(MdiIcons.formatListText,
                              size: 12, color: Colors.grey[(prefs.darkTheme) ? 300 : 700]),
                        ),
                      ),
                    ),
                    TextSpan(
                      text: data.categories?.join(", ") ?? "Keine",
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[(prefs.darkTheme) ? 200 : 800]),
                    ),
                    const WidgetSpan(
                      child: Padding(
                        padding: EdgeInsets.only(left: 4, right: 1),
                        child: Icon(MdiIcons.accountEdit, size: 14),
                      )
                    ),
                    TextSpan(
                      text: "${data.writer}",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[(prefs.darkTheme) ? 400 : 600]
                      ),
                    )
                  ]
                ),
              ),
            ],
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
