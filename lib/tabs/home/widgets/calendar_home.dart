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
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';
import 'package:kepler_app/tabs/school/calendar.dart';
import 'package:kepler_app/tabs/school/news_data.dart';
import 'package:provider/provider.dart';

/// Infoblock, der den Kalender mit Terminen des aktuellen Monats anzeigt
/// 
/// könnte eigentlich auch ein StatelessWidget sein - oder Ladevorgang könnte angepasst werden
class HomeCalendarWidget extends StatefulWidget {
  /// Home-Widget-ID - muss mit der in home.dart übereinstimmen
  final String id;
  const HomeCalendarWidget({super.key, required this.id});

  @override
  State<HomeCalendarWidget> createState() => HomeCalendarWidgetState();
}

class HomeCalendarWidgetState extends State<HomeCalendarWidget> {
  @override
  Widget build(BuildContext context) {
    return HomeWidgetBase(
      id: widget.id,
      color: colorWithLightness(keplerColorBlue, hasDarkTheme(context) ? .15 : .8),
      title: const Text("Kepler-Kalender"),
      titleColor: Theme.of(context).cardColor,
      /// Daten werden zwar gecached, aber nie aus dem Cache gelesen.
      child: FutureBuilder(
        future: loadCalendarEntries(DateTime.now()).then((out) {
          final (online, data) = out;
          if (!online) return;
          if (data == null) return;
          if (!context.mounted) return;
          Provider.of<NewsCache>(context, listen: false).replaceMonthInCalData(DateTime.now(), data);
        }),
        builder: (context, snapshot) => (snapshot.connectionState == ConnectionState.waiting) ?
        const Center(child: CircularProgressIndicator())
        : (snapshot.hasError) ? const Center(child: Text("Fehler beim Abfragen der Daten."))
        : SchoolCalendar(
          singleMonth: true,
          onDisplayedMonthChanged: (newMonth) {},
          selectedDate: null,
          displayedMonthDate: DateTime.now(),
          onSelectedDateChanged: (newDate) {
            globalCalendarNextDateToHighlightOnOpen = newDate;
            Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [NewsPageIDs.main, NewsPageIDs.calendar];
          },
        ),
      ),
    );
  }
}
