import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';
import 'package:kepler_app/tabs/school/calendar.dart';
import 'package:kepler_app/tabs/school/news_data.dart';
import 'package:provider/provider.dart';

class HomeCalendarWidget extends StatefulWidget {
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
      color: colorWithLightness(keplerColorBlue, hasDarkTheme(context) ? .2 : .8),
      title: const Text("Kepler-Kalender"),
      titleColor: Theme.of(context).cardColor,
      child: FutureBuilder(
        future: loadCalendarEntries(DateTime.now()).then((out) {
          final (online, data) = out;
          if (!online) return;
          if (data == null) return;
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
