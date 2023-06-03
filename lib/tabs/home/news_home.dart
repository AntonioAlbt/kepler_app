import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/news/news_view.dart';
import 'package:provider/provider.dart';

class HomeNewsWidget extends StatefulWidget {
  const HomeNewsWidget({super.key});

  @override
  State<HomeNewsWidget> createState() => HomeNewsWidgetState();
}

class HomeNewsWidgetState extends State<HomeNewsWidget> {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: HSLColor.fromColor(keplerColorBlue)
          .withLightness((prefs.darkTheme) ? .1 : .9)
          .toColor(),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Card(
                  child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 4, horizontal: 8),
                  child: Text(
                    "Aktuelle News",
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              )),
            ),
            AnimatedBuilder(
              animation: newsCache,
              builder: (context, child) => ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(overscroll: false),
                child: ListView.separated(
                  itemBuilder: (context, index) {
                    final data = newsCache.newsData.toList()
                      ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
                    if (index < min(3, data.length)) {
                      return ListTile(
                        title: Text(data[index].title),
                        subtitle: Text(data[index].summary,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NewsView(
                              newsLink: Uri.parse(data[index].link),
                              newsTitle: data[index].title
                            ),
                          ),
                        ),
                      );
                    } else {
                      return ListTile(
                        title: const Row(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Text("Weitere News"),
                            ),
                            Icon(Icons.open_in_new, size: 20),
                          ],
                        ),
                        onTap: () {
                          Provider.of<AppState>(context, listen: false).setNavIndex("1");
                        },
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      );
                    }
                  },
                  separatorBuilder: (context, index) => const Divider(),
                  itemCount: min(3, newsCache.newsData.length) + 1,
                  shrinkWrap: true
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
