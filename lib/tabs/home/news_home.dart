import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/widgets.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';
import 'package:kepler_app/tabs/news/news_data.dart';
import 'package:kepler_app/tabs/news/news_view.dart';
import 'package:provider/provider.dart';

class HomeNewsWidget extends StatefulWidget {
  final String id;
  const HomeNewsWidget({super.key, required this.id});

  @override
  State<HomeNewsWidget> createState() => HomeNewsWidgetState();
}

class HomeNewsWidgetState extends State<HomeNewsWidget> {
  @override
  Widget build(BuildContext context) {
    return HomeWidgetBase(
      id: widget.id,
      color: colorWithLightness(keplerColorBlue, hasDarkTheme(context) ? .1 : .9),
      title: const Text("Aktuelle News"),
      titleColor: Theme.of(context).cardColor,
      child: Consumer<NewsCache>(
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
