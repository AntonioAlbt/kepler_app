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

import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/widgets.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';
import 'package:kepler_app/tabs/school/news_data.dart';
import 'package:kepler_app/tabs/school/news_view.dart';
import 'package:provider/provider.dart';

/// zeigt Liste der 3 aktuellsten News aus Cache an (aktualisiert NewsCache **nicht**!)
class HomeNewsWidget extends StatefulWidget {
  /// Home-Widget-ID - muss mit der in home.dart übereinstimmen
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
        // TODO: test if this ScrollConfiguration can be removed -> no scrollables below it anymore?
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
                  Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [NewsPageIDs.main, NewsPageIDs.news];
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

/// einheitliche Darstellung für News-Einträge
class NewsHomeListTile extends StatelessWidget {
  /// Daten zum darzustellenden News-Eintrag
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
