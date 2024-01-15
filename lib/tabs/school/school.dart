import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/school/calendar.dart';
import 'package:kepler_app/tabs/school/news.dart';
import 'package:provider/provider.dart';

class SchoolTab extends StatefulWidget {
  const SchoolTab({super.key});

  @override
  State<SchoolTab> createState() => _SchoolTabState();
}

class _SchoolTabState extends State<SchoolTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final navPage = state.selectedNavPageIDs.last;
        if (navPage == NewsPageIDs.news) return const NewsTab();
        if (navPage == NewsPageIDs.calendar) return const CalendarTab();
        return const Text("Unbekannte Seite gefordert. Bitte schließen und erneut probieren.");
      },
    );
  }
}
