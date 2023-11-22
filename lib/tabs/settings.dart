import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/custom_color_picker.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/home/home.dart';
import 'package:kepler_app/tabs/hourtable/pages/your_plan.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

final _startPageMap = {
  PageIDs.home: "Startseite",
  PageIDs.news: "Kepler-News",
  StuPlanPageIDs.yours: "Persönlicher Stundenplan",
  StuPlanPageIDs.all: "Alle Vertretungen",
  LernSaxPageIDs.notifications: "LernSax: Benachrichtigungen",
  LernSaxPageIDs.emails: "LernSax: E-Mails",
};

final _notifKeyMap = {
  newsNotificationKey: "Neue Kepler-News",
  stuPlanNotificationKey: "Änderungen im Stundenplan",
};

class _SettingsTabState extends State<SettingsTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<Preferences>(
      builder: (context, prefs, _) {
        final sie = prefs.preferredPronoun == Pronoun.sie;
        final userType = Provider.of<AppState>(context, listen: false).userType;
        return SettingsList(
          platform: DevicePlatform.android,
          sections: [
            if (userType == UserType.nobody) SettingsSection(
              tiles: [
                SettingsTile(
                  title: const Text("Hinweis"),
                  description: Selector<Preferences, bool>(
                    selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
                    builder: (context, sie, _) => Text("${sie ? "Sie müssen" : "Du musst"} angemeldet sein, um die meisten Einstellungen zu ändern."),
                  ),
                ),
              ],
            ),
            SettingsSection(
              title: const Text("Allgemeines"),
              tiles: [
                // the way this is implemented can cause minor desync and the dialog showing the wrong system theme, but it's not that big an issue
                selectionSettingsTile(prefs.theme.toString().replaceAll("System", "System (${(deviceInDarkMode ?? false) ? "Dunkel" : "Hell"})"), AppTheme.values.map((val) {
                  if (val == AppTheme.system) {
                    return "System (${(deviceInDarkMode ?? false) ? "Dunkel" : "Hell"})";
                  } else {
                    return val.toString();
                  }
                }).toList(), "Farbmodus", (val) => prefs.theme = {"S": AppTheme.system, "D": AppTheme.dark, "H": AppTheme.light}[val.substring(0, 1)]!),
                selectionSettingsTile(prefs.preferredPronoun, Pronoun.values, "Bevorzugte Anrede", (val) => prefs.preferredPronoun = val),
                notificationSettingsTile(prefs.enabledNotifs.map((en) => _notifKeyMap[en]).where((e) => e != null).toList(), userType == UserType.nobody ? ["Neue Kepler-News"] : _notifKeyMap.values.toList(), "Benachrichtigungen", (selectedNow) {
                  prefs.enabledNotifs = selectedNow.map((e) => _notifKeyMap.entries.firstWhere((element) => element.value == e).key).toList().cast();
                }),
                selectionSettingsTile(_startPageMap[prefs.startNavPage], _startPageMap.values.toList(), "Seite, die beim Öffnen angezeigt wird", (val) => prefs.startNavPage = _startPageMap.entries.firstWhere((e) => e.value == val).key, disabled: userType == UserType.nobody),
                if (kSentryEnabled) SettingsTile.switchTile(
                  initialValue: prefs.sentryEnabled,
                  onToggle: (val) {
                    prefs.sentryEnabled = val;
                    prefs.save().then((_) {
                      if (Platform.isAndroid) SystemNavigator.pop();
                      if (Platform.isIOS) showSnackBar(text: "Bitte App schließen und neu öffnen, um Einstellungen anzuwenden.");
                    });
                  },
                  title: const Text("Sentry zur Fehleranalyse aktivieren"),
                  description: const Text(kIsBetaVersion ? "App ist Beta-Version: Sentry ist zwingend aktiviert" : "erfordert Neustart der App"),
                  enabled: !kIsBetaVersion,
                ),
                SettingsTile.navigation(
                  title: Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(child: Icon(Icons.warning_rounded, color: hasDarkTheme(context) ? Colors.amber : Colors.yellow.shade900, size: 22)),
                        const TextSpan(text: " Abmelden und neu anmelden"),
                      ],
                    ),
                  ),
                  description: const Text("Abmelden und neu mit LernSax anmelden"),
                  onPressed: (context) => showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Wirklich fortfahren?"),
                      content: Text("${sie ? "Wollen Sie sich" : "Willst Du Dich"} wirklich neu anmelden? Falls ja, wird die Verbindung zu LernSax getrennt und die Anmeldung ist erneut nötig."),
                      actions: [
                        TextButton(
                          onPressed: () {
                            // this doesn't user the showLoginScreenAgain() method, because that is intended for
                            // a login screen which the user can cancel - which isn't supposed to be possible for this
                            // one, because it's intended as a clean login
                            // this might be unneccessary, but it'd be worse to do this for the other one - parents probably would just not use the app after it closing itself

                            final creds = Provider.of<CredentialStore>(globalScaffoldContext, listen: false);
                            Provider.of<InternalState>(globalScaffoldContext, listen: false).introShown = false;
                            () async {
                              if (creds.lernSaxToken != null && creds.lernSaxLogin != null) {
                                // try to unregister this app from LernSax, but don't care if it doesn't work
                                // (most users don't check their registered apps on LernSax anyways)
                                // waiting for this to complete is still necessary
                                await unregisterApp(creds.lernSaxLogin!, creds.lernSaxToken!);
                              }
                              if (!mounted) return;

                              showLoginScreenAgain(closeable: false);
                              Navigator.pop(context);
                            }();
                          },
                          child: const Text("Ja, abmelden"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Nein, abbrechen"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SettingsSection(
              title: const Text("Startseite"),
              tiles: [
                SettingsTile.switchTile(
                  initialValue: prefs.showHomeWidgetEditOptions && userType != UserType.nobody,
                  onToggle: (val) => prefs.showHomeWidgetEditOptions = val,
                  title: const Text("Bearbeiten-Knöpfe anzeigen"),
                  description: const Text("z.B. \"Ausblenden\" und \"Verschieben\" bei Widgets anzeigen"),
                  enabled: userType != UserType.nobody,
                ),
                SettingsTile.navigation(
                  title: const Text("Widget-Reihenfolge ändern"),
                  description: const Text("Reihenfolge der Informationsblöcke auf der Startseite ändern"),
                  onPressed: (_) => openReorderHomeWidgetDialog(context),
                  enabled: userType != UserType.nobody,
                ),
              ],
            ),
            SettingsSection(
              title: const Text("Stundenplan"),
              tiles: [
                SettingsTile.navigation(
                  title: Text(userType == UserType.teacher ? "Lehrer ändern" : "Klasse oder Belegung ändern"),
                  description: Text("${sie ? "Ihre" : "Deine"} ${userType == UserType.teacher ? "Lehrer-Abkürzung" : "Klasse und/oder belegte Fächer ändern"} (für ${sie ? "Ihren" : "Deinen"} Stundenplan)"),
                  onPressed: (_) => yourStuPlanEditAction(),
                  enabled: userType != UserType.nobody,
                ),
                SettingsTile.switchTile(
                  initialValue: prefs.reloadStuPlanAutoOnceDaily,
                  onToggle: (val) => prefs.reloadStuPlanAutoOnceDaily = val,
                  title: const Text("Beim Öffnen automatisch aktualisieren"),
                  description: const Text("passiert einmal täglich beim Öffnen des Stundenplanes"),
                  enabled: userType != UserType.nobody,
                ),
                SettingsTile.navigation(
                  title: const Text("Zeit für nächsten Tag bzw. Plan"),
                  // description: const Text("ab welcher Uhrzeit der Plan für den nächsten Tag angezeigt werden soll"),
                  value: Text(prefs.timeToDefaultToNextPlanDay.toString()),
                  onPressed: (context) => showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: prefs.timeToDefaultToNextPlanDay.hour,
                      minute: prefs.timeToDefaultToNextPlanDay.minute,
                    ),
                  ).then((picked) {
                    if (picked != null) {
                      prefs.timeToDefaultToNextPlanDay = HMTime(picked.hour, picked.minute);
                    }
                  }),
                  enabled: userType != UserType.nobody,
                ),
                ColorSelectSettingsTile(
                  title: "Rahmenfarbe für Stundenplanliste",
                  current: prefs.stuPlanDataAvailableBorderColor,
                  updateData: (col) => prefs.stuPlanDataAvailableBorderColor = col!,
                  disabled: prefs.stuPlanDataAvailableBorderWidth == 0 || userType == UserType.nobody,
                ),
                ColorSelectSettingsTile(
                  title: "Rahmenfarbe 2 für Stundenplanliste - Farbe für Farbverlauf",
                  current: prefs.stuPlanDataAvailableBorderGradientColor,
                  updateData: (col) => prefs.stuPlanDataAvailableBorderGradientColor = col,
                  nullAvailable: true,
                  disabled: prefs.stuPlanDataAvailableBorderWidth == 0 || userType == UserType.nobody,
                ),
                selectionSettingsTile(
                  "${prefs.stuPlanDataAvailableBorderWidth.round()} px${prefs.stuPlanDataAvailableBorderWidth == 0 ? " (kein Rahmen)" : ""}",
                  [ "0 px (kein Rahmen)", "1 px", "3 px", "4 px", "6 px", "10 px", "15 px", "20 px" ],
                  "Rahmendicke für Stundenplanliste",
                  (val) {
                    prefs.stuPlanDataAvailableBorderWidth = double.parse(val.split(" px")[0]);
                  },
                  disabled: userType == UserType.nobody,
                ),
                SettingsTile.switchTile(
                  initialValue: prefs.considerLernSaxTasksAsCancellation,
                  onToggle: (val) => prefs.considerLernSaxTasksAsCancellation = val,
                  title: const Text("\"$cancellationALaLernSax\" als Ausfall ansehen"),
                  description: const Text("auch wenn das kein richtiger Ausfall ist"),
                  enabled: userType != UserType.nobody,
                ),
                SettingsTile.switchTile(
                  initialValue: prefs.considerLernSaxTasksAsCancellation ? prefs.showLernSaxCancelledLessonsInRoomPlan : true,
                  onToggle: (val) => prefs.showLernSaxCancelledLessonsInRoomPlan = val,
                  title: const Text("LernSax-Ausfall im Raumplan anzeigen"),
                  description: const Text("Stunden mit \"$cancellationALaLernSax\" im Raumplan anzeigen"),
                  enabled: prefs.considerLernSaxTasksAsCancellation && userType != UserType.nobody,
                ),
              ],
            ),
            SettingsSection(
              title: const Text("LernSax"),
              tiles: [
                SettingsTile.switchTile(
                  initialValue: prefs.lernSaxAutoLoadMailOnScrollBy,
                  onToggle: (val) => prefs.lernSaxAutoLoadMailOnScrollBy = val,
                  title: const Text("LernSax-Mails beim ersten Vorbeiscrollen einmalig herunterladen"),
                  description: const Text("das ist nötig, damit die Anhänge geladen werden können (verbraucht mehr Daten)"),
                  enabled: userType != UserType.nobody,
                ),
              ],
            ),
            SettingsSection(
              title: const Text("Lustiges"),
              tiles: [
                SettingsTile.switchTile(
                  initialValue: prefs.confettiEnabled,
                  onToggle: (val) {
                    return prefs.confettiEnabled = val;
                  },
                  title: const Text("Konfetti aktivieren"),
                  description: const Text("z.B. bei Ausfall oder schulfreien Tagen"),
                  enabled: userType != UserType.nobody,
                ),
              ],
            ),
          ],
        );
      }
    );
  }
}

SettingsTile selectionSettingsTile<T>(T data, List<T> values, String title, void Function(T val) updateData, {bool disabled = false}) {
  return SettingsTile.navigation(
    title: Text(title),
    value: Text(data.toString()),
    onPressed: (ctx) => showDialog(context: ctx, builder: (ctx) => AlertDialog(
      title: Text("$title auswählen", style: const TextStyle(fontSize: 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: values.map((val) => InkWell(
          onTap: () {
            updateData(val);
            Navigator.pop(ctx);
          },
          child: ListTile(
            title: Text(
              val.toString(),
              style: TextStyle(
                fontWeight: (data == val) ? FontWeight.bold : null,
              ),
            ),
          ),
        )).toList(),
      ),
    )),
    enabled: !disabled,
  );
}

SettingsTile notificationSettingsTile<T>(List<T> selected, List<T> values, String title, void Function(List<dynamic> selectedNow) updateData, {bool disabled = false}) {
  // return CustomSettingsTile(child: MultiSelectionSettingsDialog(selected: selected, values: values, title: title, updateData: updateData));
  return SettingsTile.navigation(
    title: Text(title),
    value: Text(selected.isNotEmpty ? selected.map((e) => e.toString()).join(", ") : "nichts ausgewählt"),
    onPressed: (ctx) => showDialog(
      context: ctx,
      builder: (ctx) => NotificationSettingsDialog(selected: selected, values: values, title: title, updateData: updateData),
    ),
    enabled: !disabled,
  );
}

class NotificationSettingsDialog<T> extends StatefulWidget {
  final List<T> selected;
  final List<T> values;
  final String title;
  final void Function(List<dynamic> selectedNow) updateData;

  const NotificationSettingsDialog({super.key, required this.selected, required this.values, required this.title, required this.updateData});

  @override
  State<NotificationSettingsDialog> createState() => _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState<T> extends State<NotificationSettingsDialog<T>> {
  List<T> selected = <T>[];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("${widget.title} auswählen", style: const TextStyle(fontSize: 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.values.map((val) => CheckboxListTile(
          value: selected.contains(val),
          title: Text(
            val.toString(),
            // style: TextStyle(
            //   fontWeight: (selected.contains(val)) ? FontWeight.bold : null,
            // ),
          ),
          onChanged: (checked) {
            if (checked == true && !selected.contains(val)) {
              selected.add(val);
              setState(() => ());
            } else if (checked == false && selected.contains(val)) {
              selected.remove(val);
              setState(() => selected = selected..remove(val));
            }
          },
        )).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen"),
        ),
        TextButton(
          onPressed: () {
            if (selected.isNotEmpty) {
              checkNotificationPermission().then((notifsAllowed) {
                if (notifsAllowed) {
                  widget.updateData(selected);
                  Navigator.pop(context);
                } else {
                  requestNotificationPermission().then((requestSuccessful) {
                    if (requestSuccessful) {
                      widget.updateData(selected);
                    } else {
                      widget.updateData(<T>[]);
                      showSnackBar(text: "Keine Zustimmung erteilt. Wir werden keine Benachrichtigungen senden.", error: true);
                    }
                    Navigator.pop(context);
                  });
                }
              });
            } else {
              widget.updateData(selected);
              Navigator.pop(context);
            }
          },
          child: const Text("Bestätigen"),
        ),
      ],
    );
  }

  @override
  void initState() {
    selected.addAll(widget.selected);
    super.initState();
  }
}

class ColorSelectSettingsTile extends AbstractSettingsTile {
  const ColorSelectSettingsTile({
    super.key,
    required this.title,
    required this.current,
    required this.updateData,
    this.nullAvailable = false,
    this.disabled = false,
  });

  final String title;
  final Color? current;
  final void Function(Color? data) updateData;
  final bool nullAvailable;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return SettingsTile.navigation(
      enabled: !disabled,
      title: Text(title),
      description: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: "Aktuelle Farbe: "),
            if (current != null) WidgetSpan(
              child: Transform.translate(
                offset: const Offset(1, -1),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: current,
                  ),
                ),
              ),
            ),
            TextSpan(text: current != null ? " #${current.toString().substring(10, 10+6).toUpperCase()}" : "keine"),
          ],
        ),
      ),
      onPressed: (context) => showDialog(
        context: context,
        builder: (context) => CSTileColorSelectDialog(
          updateData: updateData,
          current: current,
          nullAvailable: nullAvailable,
        ),
      ),
    );
  }
}

class CSTileColorSelectDialog extends StatefulWidget {
  const CSTileColorSelectDialog({
    super.key,
    required this.updateData,
    required this.current,
    required this.nullAvailable,
  });

  final void Function(Color? data) updateData;
  final Color? current;
  final bool nullAvailable;

  @override
  State<CSTileColorSelectDialog> createState() => _CSTileColorSelectDialogState();
}

class _CSTileColorSelectDialogState extends State<CSTileColorSelectDialog> {
  late Color selected;

  @override
  void initState() {
    selected = widget.current ?? keplerColorBlue;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final customColor = widget.current != null && ![keplerColorBlue, keplerColorOrange, keplerColorYellow].contains(widget.current);
    return AlertDialog(
      title: const Text("Farbe ändern"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            onTap: () {
              widget.updateData(keplerColorBlue);
              Navigator.pop(context);
            },
            title: Text(
              "Kepler-Farbe: Blau",
              style: TextStyle(
                fontWeight: (widget.current == keplerColorBlue) ? FontWeight.bold : null,
              ),
            ),
            trailing: Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: keplerColorBlue,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          ListTile(
            onTap: () {
              widget.updateData(keplerColorOrange);
              Navigator.pop(context);
            },
            title: Text(
              "Kepler-Farbe: Orange",
              style: TextStyle(
                fontWeight: (widget.current == keplerColorOrange) ? FontWeight.bold : null,
              ),
            ),
            trailing: Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: keplerColorOrange,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          ListTile(
            onTap: () {
              widget.updateData(keplerColorYellow);
              Navigator.pop(context);
            },
            title: Text(
              "Kepler-Farbe: Gelb",
              style: TextStyle(
                fontWeight: (widget.current == keplerColorYellow) ? FontWeight.bold : null,
              ),
            ),
            trailing: Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: keplerColorYellow,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          ListTile(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Eigene Farbe auswählen"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomHueRingPicker(
                        pickerColor: selected,
                        onColorChanged: (col) {
                          widget.updateData(col);
                          setState(() {
                            selected = col;
                          });
                        },
                        portraitOnly: true,
                        // labelTypes: const [],
                        // pickerAreaHeightPercent: 0.5,
                        enableAlpha: false,
                        colorPickerHeight: 200,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () {
                      Navigator.pop(context);
                    }, child: const Text("Fertig")),
                  ],
                ),
              ).then((_) => Navigator.pop(context));
            },
            title: Text(
              "Eigene Farbe",
              style: TextStyle(
                fontWeight: customColor ? FontWeight.bold : null,
              ),
            ),
            subtitle: customColor ? const Text("tippen, um zu ändern") : null,
            trailing: customColor
              ? Container(
                  height: 24,
                  width: 24,
                  decoration: BoxDecoration(
                    color: selected,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
              : null,
          ),
          if (widget.nullAvailable) ListTile(
            onTap: () {
              widget.updateData(null);
              Navigator.pop(context);
            },
            title: Text(
              "Keine",
              style: TextStyle(
                fontWeight: (widget.current == null) ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
