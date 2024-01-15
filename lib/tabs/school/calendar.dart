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

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
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
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CalendarDatePicker2(
            config: CalendarDatePicker2Config(
              firstDayOfWeek: 1,
              dayBuilder: ({required date, decoration, isDisabled, isSelected, isToday, textStyle}) {
                final evtCount = _getDateEventCount(date);
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
            value: [_selectedDate],
            onValueChanged: (selected) => setState(() => _selectedDate = selected.first!),
            onDisplayedMonthChanged: (date) {
              setState(() {
                _displayedMonthDate = date;
                _selectedDate = null;
              });
              _loadData();
            },
            displayedMonthDate: _displayedMonthDate,
          ),
          if (_selectedDate != null) CalendarDateShowcase(date: _selectedDate!),
        ],
      ),
    );
  }

  int _getDateEventCount(DateTime date) {
    return Provider.of<NewsCache>(context, listen: false).getCalEntryDataForDay(date).length;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() => _loading = true);
    loadCalendarEntries(_displayedMonthDate).then((out) {
      final (online, data) = out;
      setState(() => _loading = false);
      if (!online) {
        showSnackBar(text: "Keine Internetverbindung.");
        return;
      }
      if (data == null) return;
      Provider.of<NewsCache>(context, listen: false).replaceMonthInCalData(_displayedMonthDate, data);
    });
  }
}

class CalendarDateShowcase extends StatefulWidget {
  final DateTime date;

  const CalendarDateShowcase({super.key, required this.date});

  @override
  State<CalendarDateShowcase> createState() => _CalendarDateShowcaseState();
}

final _niceDateFormat = DateFormat("dd.MM.yyyy");
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
                      "Am ${widget.date.day}.${widget.date.month}. finden am JKG keine Veranstaltungen statt.",
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
