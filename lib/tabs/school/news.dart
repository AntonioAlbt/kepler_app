// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2023-2025 Antonio Albert

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

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/rainbow.dart';
import 'package:kepler_app/tabs/school/news_view.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:kepler_app/tabs/school/news_data.dart';
import 'package:provider/provider.dart';

extension StringExtension on String {
  String truncateTo(int maxLength) =>
      (length <= maxLength) ? this : '${substring(0, maxLength)}...';
  
  String stripHtmlIfNeeded() => replaceAll(RegExp(r"<[^>]*>|&[^;]+;"), " ");
}

final newsTabKey = GlobalKey<NewsTabState>();

/// zeigt Kepler-News von RSS-Feed an und cached sie
class NewsTab extends StatefulWidget {
  NewsTab() : super(key: newsTabKey);

  @override
  State<NewsTab> createState() => NewsTabState();
}

class NewsTabState extends State<NewsTab> {
  double opacity = 0;
  int lastNewsPage = 0;
  bool noMoreNews = false;
  bool loading = false;
  bool _showFilterBar = false;
  String _filterCategory = "";

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

  void reload() {
    if (!loading) _resetNews();
  }

  void toggleFilterMode() {
    setState(() {
      _showFilterBar = !_showFilterBar;
      if (!_showFilterBar) _filterCategory = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<NewsCache, Preferences>(
      builder: (context, newsCache, prefs, _) {
        final loadedNews = newsCache.newsData.asMap().map((i, d) => MapEntry(i, NewsEntry(data: d, count: i, prefs: prefs,))).values.toList()
          ..sort((a, b) => b.data.createdDate.compareTo(a.data.createdDate));
        return Scaffold(
          /// lädt automatisch mehr News, wenn der Benutzer ganz nach unten gescrollt hat
          body: Column(
            children: [
              if (loadedNews.isNotEmpty) AnimatedSize(
                duration: const Duration(milliseconds: 100),
                alignment: Alignment.topCenter,
                child: (_showFilterBar) ? Padding(
                  padding: const EdgeInsets.only(top: 16, left: 12, right: 12, bottom: 8),
                  child: DropdownMenu(
                    label: Text("Nachrichten nach Kategorie filtern"),
                    width: double.infinity,
                    dropdownMenuEntries: loadedNews.map((n) => (n.data.categories ?? [])).reduce((a, b) => a + b).toSet()
                      .map((category) => DropdownMenuEntry(value: category, label: category)).toList()
                        ..add(DropdownMenuEntry(value: "", label: "alle")),
                    initialSelection: "",
                    leadingIcon: Icon(Icons.filter_alt),
                    onSelected: (val) => setState(() => _filterCategory = val!),
                  ),
                ) : SizedBox(height: 0, width: double.infinity),
              ),
              Expanded(
                child: LazyLoadScrollView(
                  onEndOfPage: () {
                    if (_filterCategory == "") _loadMoreNews();
                  },
                  child: Scrollbar(
                    controller: _controller,
                    radius: const Radius.circular(4),
                    thickness: 4.75,
                    child: RefreshIndicator(
                      /// beim Neuladen wird der Cache komplett geleert
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
                              child: (_filterCategory != "") ? ListTile(
                                title: Text("Wegen der Filterung werden gerade keine weiteren News geladen."),
                                subtitle: Text("Bitte ${prefs.preferredPronoun == Pronoun.sie ? "entfernen Sie" : "entferne"} den Filter, um weitere abzufragen."),
                              ) : ListTile(
                                leading: const CircularProgressIndicator(),
                                title: Text("Lädt${(loadedNews.isNotEmpty) ? " mehr" : ""} News..."),
                              ),
                            );
                          }

                          if (!(loadedNews[index - 1].data.categories ?? []).contains(_filterCategory) && _filterCategory != "") return SizedBox.shrink();

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
              ),
            ],
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

  /// lädt jeweils eine Seite neue Nachrichten, oder alle neuen Nachrichten seit letztem Öffnen
  Future _loadMoreNews() async {
    if (noMoreNews || loading) return;
    if (_newsCache.newsData.isNotEmpty) {
      final newStartNews = await loadAllNewNews(_newsCache.newsData.first.link);
      if (newStartNews != null) _newsCache.insertNewsData(0, newStartNews);
    }
    if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        noMoreNews = true;
        loading = false;
      });
    } else {
      /// Duplikate entfernen (falls weniger als 10 neue Nachrichten dazugekommen sind)
      newNewsData.removeWhere((e1) => _newsCache.newsData.any((e2) => e1.link == e2.link));
      while (newNewsData.length < 9 && lastNewsPage < 50) {
        lastNewsPage++;
        final moreData = await loadNews(lastNewsPage);
        if (moreData == null || moreData.isEmpty) break;
        newNewsData.addAll(moreData);
      }
      _newsCache.addNewsData(newNewsData);
      lastNewsPage++;
      if (!mounted) return;
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
  /// "berechnet" Farbe für NewsEntry abhängig von Index
  Color getNEntryCol(int count, bool darkMode) {
    return HSLColor.fromColor(_colors[count % _colors.length])
        .withLightness((darkMode) ? .2 : .8)
        .withSaturation((darkMode) ? .3 : .7)
        .toColor();
  }
}

/// ListEntry für Kepler-News
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
    return RainbowWrapper(
      builder: (context, rcolor) {
        return Card(
          color: rcolor != null ? Color.alphaBlend(rcolor.withValues(alpha: .5), color) : color,
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
                          text: DateFormat.yMMMMd("de-DE").format(data.createdDate),
                          style: TextStyle(fontSize: 13, color: Colors.grey[(prefs.darkTheme) ? 200 : 800]),
                        ),
                        WidgetSpan(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10, right: 3),
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
                  // RichText(
                  //   text: TextSpan(
                  //     children: [
                  //       // WidgetSpan(
                  //       //   child: Padding(
                  //       //     padding: const EdgeInsets.only(left: 4, right: 1),
                  //       //     child: Icon(MdiIcons.accountEdit, size: 14),
                  //       //   )
                  //       // ),
                  //       // TextSpan(
                  //       //   text: "${data.writer}",
                  //       //   style: TextStyle(
                  //       //     fontSize: 10,
                  //       //     color: Colors.grey[(prefs.darkTheme) ? 400 : 600]
                  //       //   ),
                  //       // ),
                  //     ],
                  //   ),
                  // ),
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
    );
  }
}

void newsTabRefreshAction() {
  newsTabKey.currentState?.reload();
}

void newsTabToggleFilterAction() {
  newsTabKey.currentState?.toggleFilterMode();
}
