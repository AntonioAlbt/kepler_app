import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
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
  StuPlanPageIDs.main: "Aktueller Stundenplan",
  LernSaxPageIDs.main: "LernSax-Infos",
};

class _SettingsTabState extends State<SettingsTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<Preferences>(
      builder: (context, prefs, _) {
        final sie = prefs.preferredPronoun == Pronoun.sie;
        final userType = Provider.of<AppState>(context, listen: false).userType;
        return SettingsList(
          sections: [
            SettingsSection(
              title: const Text("Allgemeines"),
              tiles: [
                selectionSettingsTile(prefs.theme, AppTheme.values, "Farbmodus", (val) => prefs.theme = val),
                selectionSettingsTile(prefs.preferredPronoun, Pronoun.values, "Bevorzugte Anrede", (val) => prefs.preferredPronoun = val),
                selectionSettingsTile(_startPageMap[prefs.startNavPage], _startPageMap.values.toList(), "Seite, die beim Öffnen angezeigt wird", (val) => prefs.startNavPage = _startPageMap.entries.firstWhere((e) => e.value == val).key),
                SettingsTile.navigation(
                  title: const Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(child: Icon(Icons.warning_rounded, color: Colors.amber, size: 22)),
                        TextSpan(text: " Abmelden und neu anmelden"),
                      ],
                    ),
                  ),
                  description: const Text("Abmelden und nach Neustart der App neu mit LernSax anmelden"),
                  onPressed: (context) => showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Wirklich fortfahren?"),
                      content: Text("${sie ? "Wollen Sie sich" : "Willst Du Dich"} wirklich neu anmelden? Falls ja, wird die App geschlossen und die Anmeldung ist nach neuem Öffnen erneut nötig."),
                      actions: [
                        TextButton(
                          onPressed: () {
                            final creds = Provider.of<CredentialStore>(globalScaffoldState.context, listen: false);
                            creds.lernSaxLogin = "";
                            creds.lernSaxToken = null;
                            creds.vpUser = null;
                            creds.vpPassword = null;
                            Provider.of<InternalState>(globalScaffoldState.context, listen: false).introShown = false;
                            SystemChannels.platform.invokeMethod('SystemNavigator.pop');
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
              title: const Text("Stundenplan"),
              tiles: [
                SettingsTile.navigation(
                  title: Text(userType == UserType.teacher ? "Lehrer ändern" : "Klasse oder Belegung ändern"),
                  description: Text("${sie ? "Ihre" : "Deine"} ${userType == UserType.teacher ? "Lehrer-Abkürzung" : "Klasse und/oder belegte Fächer ändern"} (für ${sie ? "Ihren" : "Deinen"} Stundenplan)"),
                  onPressed: (_) => yourStuPlanEditAction(),
                ),
                SettingsTile.switchTile(
                  initialValue: prefs.considerLernSaxTasksAsCancellation,
                  onToggle: (val) => prefs.considerLernSaxTasksAsCancellation = val,
                  title: const Text("\"$cancellationALaLernSax\" als Ausfall ansehen"),
                  description: const Text("auch wenn das kein richtiger Ausfall ist"),
                ),
                SettingsTile.switchTile(
                  initialValue: prefs.considerLernSaxTasksAsCancellation ? prefs.showLernSaxCancelledLessonsInRoomPlan : true,
                  onToggle: (val) => prefs.showLernSaxCancelledLessonsInRoomPlan = val,
                  title: const Text("LernSax-Ausfall im Raumplan anzeigen"),
                  description: const Text("Stunden mit \"$cancellationALaLernSax\" im Raumplan anzeigen"),
                  enabled: prefs.considerLernSaxTasksAsCancellation,
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
                ),
              ],
            ),
          ],
        );
      }
    );
  }
}

SettingsTile selectionSettingsTile<T>(T data, List<T> values, String title, void Function(T val) updateData) {
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
  );
}
