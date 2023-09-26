import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/widgets.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/news/news_data.dart';
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
      color: colorWithLightness(keplerColorBlue, hasDarkTheme(context) ? .1 : .9),
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
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text(
                    "Aktuelle News",
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              )),
            ),
            Consumer<NewsCache>(
              builder: (context, newsCache, _) => ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(overscroll: false),
                child: Column(
                  children: separatedListViewWithDividers([
                    ...[0, 1, 2].map((i) => (newsCache.newsData.length > i) ? NewsHomeListTile(newsCache.newsData[i]) : null).where((w) => w != null).toList().cast(),
                    ListTile(
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
                        Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [PageIDs.news];
                      },
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                    ),
                  ]),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class NewsHomeListTile extends StatelessWidget {
  final NewsEntryData data;
  const NewsHomeListTile(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(data.title),
      subtitle: Text(data.summary, maxLines: 1, overflow: TextOverflow.ellipsis),
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsView(newsLink: Uri.parse(data.link), newsTitle: data.title),
        ),
      ),
    );
  }
}
