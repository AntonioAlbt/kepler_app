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

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';
import 'package:kepler_app/tabs/school/news_data.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

DateTime? globalCalendarNextDateToHighlightOnOpen;

final calendarTabKey = GlobalKey<CalendarTabState>();

class CalendarTab extends StatefulWidget {
  CalendarTab() : super(key: calendarTabKey);

  @override
  State<CalendarTab> createState() => CalendarTabState();
}

class CalendarTabState extends State<CalendarTab> {
  DateTime? _selectedDate = DateTime.now();
  DateTime _displayedMonthDate = DateTime.now();
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text("Lädt Kalender..."),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SchoolCalendar(
              onDisplayedMonthChanged: (date) {
                setState(() {
                  _displayedMonthDate = date;
                  _selectedDate = null;
                });
                _loadData();
              },
              onSelectedDateChanged: (date) => setState(() => _selectedDate = date),
              selectedDate: _selectedDate,
              displayedMonthDate: _displayedMonthDate,
            ),
            if (_selectedDate != null) CalendarDateShowcase(date: _selectedDate!),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (globalCalendarNextDateToHighlightOnOpen != null) {
      _selectedDate = globalCalendarNextDateToHighlightOnOpen;
      _displayedMonthDate = globalCalendarNextDateToHighlightOnOpen ?? DateTime.now();
      globalCalendarNextDateToHighlightOnOpen = null;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final (online, data) = await loadCalendarEntries(_displayedMonthDate);
    setState(() => _loading = false);
    if (!online) {
      showSnackBar(text: "Keine Internetverbindung.");
      return;
    }
    if (data == null) return;
    Provider.of<NewsCache>(context, listen: false).replaceMonthInCalData(_displayedMonthDate, data);
  }

  void reload() {
    if (!_loading) _loadData();
  }
}

class SchoolCalendar extends StatefulWidget {
  final DateTime? selectedDate;
  final DateTime displayedMonthDate;
  final void Function(DateTime? newDate) onSelectedDateChanged;
  final void Function(DateTime newMonth) onDisplayedMonthChanged;
  final bool singleMonth;

  const SchoolCalendar({super.key, required this.onSelectedDateChanged, required this.onDisplayedMonthChanged, this.singleMonth = false, required this.selectedDate, required this.displayedMonthDate});

  @override
  State<SchoolCalendar> createState() => _SchoolCalendarState();
}

class _SchoolCalendarState extends State<SchoolCalendar> {
  @override
  Widget build(BuildContext context) {
    return CalendarDatePicker2(
      config: CalendarDatePicker2Config(
        nextMonthIcon: widget.singleMonth ? const SizedBox.shrink() : null,
        lastMonthIcon: widget.singleMonth ? const SizedBox.shrink() : null,
        firstDayOfWeek: 1,
        dayBuilder: ({required date, decoration, isDisabled, isSelected, isToday, textStyle}) {
          final evtCount = Provider.of<NewsCache>(context, listen: false).getCalEntryDataForDay(date).length;
          return Row(
            children: [
              const Spacer(),
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: decoration,
                  child: Center(
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            MaterialLocalizations.of(context).formatDecimal(date.day),
                            style: textStyle,
                          ),
                        ),
                        if (evtCount > 0) Transform.scale(
                          scale: .99,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(BorderSide(color: (isToday ?? false) ? Colors.green : (date.isBefore(DateTime.now()) ? keplerColorOrange : keplerColorYellow), width: 3))
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          );
        },
      ),
      value: [widget.selectedDate],
      onValueChanged: (selected) {
        widget.onSelectedDateChanged(selected.first!);
      },
      onDisplayedMonthChanged: (date) {
        widget.onDisplayedMonthChanged(date);
      },
      displayedMonthDate: widget.displayedMonthDate,
    );
  }
}

class CalendarDateShowcase extends StatefulWidget {
  final DateTime date;

  const CalendarDateShowcase({super.key, required this.date});

  @override
  State<CalendarDateShowcase> createState() => _CalendarDateShowcaseState();
}

final _niceDateFormat = DateFormat("dd.MM.yyyy");
final _niceShortDateFormat = DateFormat("dd.MM.");
class _CalendarDateShowcaseState extends State<CalendarDateShowcase> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: HomeWidgetBase(
        id: "who did this XDDDD",
        color: Theme.of(context).cardColor,
        titleColor: hasDarkTheme(context) ? Theme.of(context).cardColor : colorWithLightness(Theme.of(context).cardColor, .95),
        overrideShowIcons: false,
        title: Text("Veranstaltungen am ${_niceDateFormat.format(widget.date)}"),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 100),
          child: Consumer<NewsCache>(
            builder: (context, news, _) {
              final entries = news.getCalEntryDataForDay(widget.date);
              if (entries.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      "Am ${_niceShortDateFormat.format(widget.date)} finden am JKG keine Veranstaltungen statt.",
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: entries.map((dt) => Column(
                    children: [
                      ListTile(
                        title: Html(data: dt.title),
                        subtitle: Html(
                          data: dt.description,
                          onLinkTap: (url, attributes, element) {
                            if (url == null) return;
                            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) {
                              showSnackBar(text: "Fehler beim Öffnen.", duration: const Duration(seconds: 1));
                              return false;
                            });
                          },
                        ),
                      ),
                      if (dt.startDate != null) Padding(
                        padding: const EdgeInsets.only(left: 24, top: 4),
                        child: Row(
                          children: [
                            const Icon(MdiIcons.clock),
                            Text(" ab ${DateFormat("HH:mm").format(dt.startDate!)} Uhr${dt.endDate != null ? " bis ${DateFormat("HH:mm").format(dt.endDate!)} Uhr" : ""}"),
                          ],
                        ),
                      ),
                      if (dt.venueName != null) Padding(
                        padding: const EdgeInsets.only(left: 24, top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on),
                            Text(" ${dt.venueName!}"),
                          ],
                        ),
                      ),
                      if (dt.organizerName != null) Padding(
                        padding: const EdgeInsets.only(left: 24, top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.person),
                            Text(" ${dt.organizerName!}"),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: ElevatedButton(
                          onPressed: () => launchUrl(Uri.parse(dt.link), mode: LaunchMode.externalApplication),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.public),
                              ),
                              Text("Im Browser ansehen"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )).toList(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

void calendarTabRefreshAction() {
  calendarTabKey.currentState?.reload();
}
