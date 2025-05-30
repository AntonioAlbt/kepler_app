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
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/tasks.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/tabs/home/widgets/calendar_home.dart';
import 'package:kepler_app/tabs/home/widgets/foucault_home.dart';
import 'package:kepler_app/tabs/home/widgets/ls_link_home.dart';
import 'package:kepler_app/tabs/home/widgets/ls_mails_home.dart';
import 'package:kepler_app/tabs/home/widgets/ls_notifs_home.dart';
import 'package:kepler_app/tabs/home/widgets/ls_tasks_home.dart';
import 'package:kepler_app/tabs/home/widgets/news_home.dart';
import 'package:kepler_app/tabs/home/widgets/stuplan_home.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

/// Standard-Startseite der App, mit Liste von Infoblöcken ("Widgets") für alle wichtigen Bestandteile der App
class HomepageTab extends StatefulWidget {
  const HomepageTab({super.key});

  @override
  State<HomepageTab> createState() => _HomepageTabState();
}

/// "Registrierung" der Widgets. Die IDs werden zum Ausblenden und Anordnen der Widgets verwendet, und auch,
/// um die Widgets am Anfang überhaupt auf der Startseite anzuzeigen.
/// 
/// Wenn ein neues Widget hinzugefügt werden soll, muss es hier in Form von
///   "widget_id": ("Widget-Titel", Widget(id: "widget_id"))
/// eingetragen werden.
final homeWidgetKeyMap = {
  "news": ("Kepler-News", const HomeNewsWidget(id: "news")),
  "stuplan": ("Aktuelle Vertretungen", const HomeStuPlanWidget(id: "stuplan")),
  "lernsax_browser": ("LernSax öffnen", const HomeLSLinkWidget(id: "lernsax_browser")),
  "lernsax_notifs": ("LernSax: Benachrichtigungen", const HomeLSNotifsWidget(id: "lernsax_notifs")),
  "lernsax_mails": ("LernSax: E-Mails", const HomeLSMailsWidget(id: "lernsax_mails")),
  "lernsax_tasks": ("LernSax: Aufgaben", const HomeLSTasksWidget(id: "lernsax_tasks")),
  "calendar": ("Kepler-Kalender", const HomeCalendarWidget(id: "calendar")),
  "foucault": ("Foucaultsches Pendel", const HomePendulumWidget(id: "foucault")),
};

/// welche Widgets in welcher Reihenfolge für nicht eingeloggte Benutzer angezeigt werden sollen
/// - diese können die Reihenfolge nicht ändern und auch keine Widgets aus-/einblenden
final widgetsForNotLoggedIn = ["news", "calendar", "stuplan", "foucault"];

class _HomepageTabState extends State<HomepageTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Consumer<Preferences>(
            builder: (context, prefs, _) {
              return Column(
                children: [
                  /// Hauptbestandteil der Startseite -> alle noch verfügbaren Widgets, die nicht ausgeblendet sind, anzeigen
                  ...prefs.homeScreenWidgetOrderList.where((id) => homeWidgetKeyMap.keys.contains(id) && !prefs.hiddenHomeScreenWidgets.contains(id)).map((widget) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: homeWidgetKeyMap[widget]?.$2,
                  )),
                  if (prefs.hiddenHomeScreenWidgets.length == homeWidgetKeyMap.keys.length) const Text("Alle Widgets sind ausgeblendet."),
                  TextButton(
                    onPressed: Provider.of<AppState>(context).userType == UserType.nobody ? null : () => openReorderHomeWidgetDialog(),
                    child: const Text("Ausgeblendete Widgets verwalten"),
                  ),
                  if (kDebugFeatures) ElevatedButton(
                    onPressed: () {
                      runNewsFetchTask();
                      showSnackBar(text: "sent");
                    },
                    child: const Text("Run news task"),
                  ),
                  if (kDebugFeatures) ElevatedButton(
                    onPressed: () {
                      runStuPlanFetchTask();
                      showSnackBar(text: "sent");
                    },
                    child: const Text("Run stuplan task"),
                  ),
                  if (kDebugFeatures) ElevatedButton(
                    onPressed: () {
                      sendNotification(title: "StuPlan Notif", body: "Info about the stuplan", notifKey: stuPlanNotificationKey);
                      showSnackBar(text: "sent");
                    },
                    child: const Text("Send stuplan notif"),
                  ),
                  if (kDebugFeatures) ElevatedButton(
                    onPressed: () {
                      Provider.of<Preferences>(context, listen: false).setOldColorSchemeAsTest();
                      showSnackBar(text: "done");
                    },
                    child: const Text("do color test thing"),
                  ),
                  if (kDebugFeatures) ElevatedButton(
                    onPressed: () {
                      final r = Provider.of<StuPlanData>(context, listen: false).guessSummerHolidayBounds();
                      if (r == null) return showSnackBar(text: "ITS null!");
                      final (start, end) = r;
                      showSnackBar(text: "Start: $start - End: $end");
                    },
                    child: const Text("Guess summer holiday bounds"),
                  ),
                  if (kDebugFeatures) ElevatedButton(
                    onPressed: () {
                      context.read<InternalState>().lastClassReminderYear = 1900;
                      showSnackBar(text: "resetted");
                    },
                    child: const Text("Reset last shown date"),
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final prefs = Provider.of<Preferences>(context, listen: false);
    final istate = Provider.of<InternalState>(context, listen: false);
    final notLoggedIn = Provider.of<AppState>(context, listen: false).userType == UserType.nobody;
    /// ermitteln, welche Widgets neu hinzugefügt werden sollen, da der Benutzer sie noch nicht hatte
    /// -> auch dafür, wenn neue Widgets zur App hinzugefügt werden - werden damit direkt auf der Startseite
    /// von Benutzern hinzugefügt
    final newIds = homeWidgetKeyMap.keys.where((id) => !istate.widgetsAdded.contains(id) && !prefs.homeScreenWidgetOrderList.contains(id)).where((id) {
      return notLoggedIn ? widgetsForNotLoggedIn.contains(id) : true;
    }).toList();
    /// damit der State nicht beim Rendern verändert wird, muss ein PostFrameCallback verwendet werden
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prefs.homeScreenWidgetOrderList = prefs.homeScreenWidgetOrderList.where((id) {
        return homeWidgetKeyMap.keys.contains(id) && (notLoggedIn ? widgetsForNotLoggedIn.contains(id) : true);
      }).toList() + newIds;
      prefs.homeScreenWidgetOrderList = prefs.homeScreenWidgetOrderList.toSet().toList();
      prefs.hiddenHomeScreenWidgets = prefs.hiddenHomeScreenWidgets.where((e) => e != "").toSet().toList();
      istate.widgetsAdded = newIds;
    });
  }
}

/// öffnet den Dialog für das Ändern der Reihenfolge der Widgets
/// - verwendet globalen Context, damit beim Ausblenden des öffnenden Widgets nicht das Rendering fehlschlägt
Future<void> openReorderHomeWidgetDialog() => showDialog(context: globalScaffoldContext, builder: (context) {
  if (Provider.of<AppState>(context, listen: false).userType == UserType.nobody) {
    return AlertDialog(title: const Text("Fehler"), content: const Text("Anmeldung erforderlich."), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
    ]);
  }
  final prefs = Provider.of<Preferences>(context);
  return AnimatedBuilder(
    animation: prefs,
    builder: (context, _) => AlertDialog(
      title: const Text("Reihenfolge"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          children: [
            const Text("Zum Verschieben auf Eintrag gedrückt halten."),
            Expanded(
              child: ReorderableListView(
                shrinkWrap: true,
                onReorder: (int oldIndex, int newIndex) {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final l = prefs.homeScreenWidgetOrderList;
                  final old = l.removeAt(oldIndex);
                  l.insert(newIndex, old);
                  prefs.homeScreenWidgetOrderList = l;
                },
                children: prefs.homeScreenWidgetOrderList.map((id) => Padding(
                  key: ValueKey(id),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      IconButton(icon: Icon(prefs.hiddenHomeScreenWidgets.contains(id) ? MdiIcons.eyeOff : MdiIcons.eye, size: 20), onPressed: () {
                        prefs.hiddenHomeScreenWidgets = (prefs.hiddenHomeScreenWidgets.contains(id)) ? (prefs.hiddenHomeScreenWidgets..remove(id)) : (prefs.hiddenHomeScreenWidgets..add(id));
                      }),
                      Flexible(
                        child: Text(
                          homeWidgetKeyMap[id]?.$1 ?? "Unbekannt",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Schließen"),
        ),
      ],
    ),
  );
});
