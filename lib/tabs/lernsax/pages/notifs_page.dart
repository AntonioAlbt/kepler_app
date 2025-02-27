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
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/rainbow.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

final lernSaxTimeFormatWithSeconds = DateFormat("dd.MM.yyyy HH:mm:ss");
final lernSaxTimeFormat = DateFormat("dd.MM.yyyy HH:mm");

final lsNotifPageKey = GlobalKey<LSNotificationPageState>();

void lernSaxNotifsRefreshAction() {
  lsNotifPageKey.currentState?.loadData();
}

/// Auflistungsseite für LS-Benachrichtigungen, mehr Infos zu jeder in Dialog verfügbar
class LSNotificationPage extends StatefulWidget {
  /// zu verwendender LS-Login
  final String login;
  /// zu verwendendes LS-Token
  final String token;
  /// wird nicht der primäre LS-Account verwendet?
  final bool alternative;

  LSNotificationPage(this.login, this.token, this.alternative) : super(key: lsNotifPageKey);

  @override
  State<LSNotificationPage> createState() => LSNotificationPageState();
}

class LSNotificationPageState extends State<LSNotificationPage> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Consumer<LernSaxData>(
      builder: (context, lsdata, child) {
        if (lsdata.notifications == null) {
          return const Center(
            child: Text(
              "Fehler beim Laden von Benachrichtigungen.",
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          );
        }
        if (lsdata.notifications?.isEmpty ?? true) {
          return const Center(
            child: Text(
              "Keine Benachrichtigungen vorhanden.",
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          );
        }
        return RainbowWrapper(
          builder: (context, color) {
            return RefreshIndicator(
              onRefresh: loadData,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: lsdata.notifications!.length,
                itemBuilder: (context, i) {
                  final notif = lsdata.notifications![i];
                  return Padding(
                    padding: (i > 0) ? const EdgeInsets.symmetric(horizontal: 4) : const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
                    child: LSNotificationTile(notif: notif, iconColor: color),
                  );
                },
                separatorBuilder: (context, i) => const Divider(),
              ),
            );
          }
        );
      }
    );
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => _loading = true);
    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final (online, data) = await lernsax.getNotifications(creds.lernSaxLogin!, creds.lernSaxToken!, startId: lsdata.notifications?.firstOrNull?.id);
    final text = (online == false && lsdata.lastNotificationsUpdateDiff.inHours >= 24 && lsdata.notifications != null) ? " Hinweis: Die Daten sind älter als 24 Stunden. Es könnten neue Benachrichtigungen verfügbar sein." : "";
    if (!online) {
      showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?$text", error: true, clear: true);
    } else if (data == null) {
      showSnackBar(textGen: (sie) => "Fehler beim Abfragen neuer Benachrichtungen. Bitte ${sie ? "probieren Sie" : "probiere"} es später erneut.$text", error: true, clear: true);
    } else {
      lsdata.lastNotificationsUpdate = DateTime.now();
      lsdata.notifications = (lsdata.notifications ?? []) + data;
      showSnackBar(text: "Benachrichtigungen erfolgreich aktualisiert.", duration: const Duration(seconds: 1));
    }
    setState(() => _loading = false);
  }
}

/// Map für Benachrichtigung.object -> IconData
final iconObjectMap = {
  "files": MdiIcons.fileMultiple,
  "mail": MdiIcons.email,
  "trusts": MdiIcons.login,
  "messenger": MdiIcons.mail,
  "tasks": MdiIcons.checkCircleOutline,
  "board": MdiIcons.bulletinBoard,
  "calendar": MdiIcons.calendar,
};

/// Benachrichtigungs.object's, für die die Daten nicht angezeigt werden sollen
final hideData = ["files", "trusts"];

/// ListTile für einheitliche Darstellung von LS-Benachrichtigungen in einer ListView
class LSNotificationTile extends StatelessWidget {
  const LSNotificationTile({
    super.key,
    required this.notif,
    this.darkerClock = false,
    this.iconColor,
  });

  /// darzustellende Benachrichtigung
  final LSNotification notif;
  /// Icons dunkler darstellen
  final bool darkerClock;
  /// stattdessen zu verwendende Farbe für alle Icons
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        textStyle: Theme.of(context).textTheme.bodyMedium,
        foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => showDialog(context: context, builder: (ctx) => generateLernSaxNotifInfoDialog(ctx, notif)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(MdiIcons.clock, size: 16, color: iconColor ?? (darkerClock ? Colors.grey.shade900 : Colors.grey)),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(lernSaxTimeFormatWithSeconds.format(notif.date)),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(iconObjectMap[notif.object], color: iconColor ?? (darkerClock ? Colors.grey.shade900 : Colors.grey)),
              Flexible(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(notif.message),
              )),
            ],
          ),
          // dont care about group login because no user can recognize that ever
          if (notif.fromUserName != null || notif.fromGroupName != null || notif.fromUserLogin != null) Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Row(
              children: [
                if (notif.hasGroupName) Icon(MdiIcons.humanMaleBoard, color: iconColor ?? (darkerClock ? Colors.grey.shade900 : Colors.grey)),
                if (notif.hasGroupName) Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text("${notif.fromGroupName}"),
                  ),
                ),
                if (notif.hasUserData) Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(MdiIcons.account, color: iconColor ?? (darkerClock ? Colors.grey.shade900 : Colors.grey)),
                ),
                if (notif.hasUserData) Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text("${notif.fromUserName ?? notif.fromUserLogin}"),
                  ),
                ),
              ],
            ),
          ),
          if (notif.data != null && !hideData.contains(notif.object)) Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Row(
              children: [
                Icon(notif.object == "mail" ? MdiIcons.inboxArrowDown : MdiIcons.formatListText, color: iconColor),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(notif.object == "mail" ? "von ${notif.data}" : notif.data!),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Map von object -> NavPage ID für In-App-Navigation und Vorschlag von Aktion in Dialog
final _appPageObjectMap = {
  "mail": LernSaxPageIDs.emails,
  "tasks": LernSaxPageIDs.tasks,
};


Widget generateLernSaxNotifInfoDialog(BuildContext context, LSNotification notif) {
  return AlertDialog(
    title: const Text("Infos zur Benachrichtigung"),
    content: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoDialogEntry(icon: Icons.numbers, text: "ID: ${notif.id}", paddingTop: EdgeInsets.zero),
          InfoDialogEntry(icon: Icons.access_time_filled, text: lernSaxTimeFormatWithSeconds.format(notif.date)),
          InfoDialogEntry(icon: Icons.info, text: notif.message),
          if (notif.data != null) InfoDialogEntry(icon: MdiIcons.shape, text: notif.data!),
          if (notif.hasUserData) InfoDialogEntry(icon: Icons.person, text: "${notif.fromUserName ?? "Kein Benutzer"}${notif.fromUserLogin != null && notif.fromUserName != notif.fromUserLogin ? " (E-Mail: ${notif.fromUserLogin})" : ""}"),
          if (notif.hasGroupName) InfoDialogEntry(icon: Icons.group_sharp, text: "${notif.fromGroupName ?? "Keine Gruppe"}${notif.fromGroupLogin != null ? " (Login: ${notif.fromGroupLogin})" : ""}"),
          // InfoDialogEntry(icon: Icons.check_box, text: notif.unread ? "Ungelesen" : "Gelesen"),
          InfoDialogEntry(icon: Icons.abc, text: notif.messageTypeId),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Schließen")),
      TextButton(
        onPressed: () {
          Navigator.pop(context);
          final appPageId = _appPageObjectMap[notif.object];
          if (appPageId != null) {
            Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [LernSaxPageIDs.main, appPageId];
          } else {
            final creds = Provider.of<CredentialStore>(context, listen: false);
            // the target url path is the link to the system notifications page
            lernsax.getSingleUseLoginLink(creds.lernSaxLogin!, creds.lernSaxToken!, targetUrlPath: "/wws/240761.php").then((data) {
              final (online, link) = data;
              if (!online) {
                showSnackBar(text: "Fehler bei der Verbindung zu LernSax.", error: true, clear: true);
              } else if (link == null) {
                showSnackBar(text: "Fehler bei Erstellung des LernSax-Links.", error: true, clear: true);
              } else {
                launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication).catchError((_) {
                  showSnackBar(text: "Fehler beim Öffnen des Links.");
                  return false;
                });
              }
            });
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Da bei einer Mail-Benachrichtigung keine Ordner-ID/ID der Mail selbst übergeben wird,
            /// kann man nicht direkt auf die Mail antworten oder die Mail direkt öffnen -_- (coole API)
            Text("${_appPageObjectMap.containsKey(notif.object) ? "In App" : "Im Browser"} öffnen", style: const TextStyle(fontWeight: FontWeight.w600)),
            if (!_appPageObjectMap.containsKey(notif.object)) const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.open_in_new, size: 16),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Eintrag im Dialog, damit alle ordentlich angezeigt werden
/// TODO: ausprobieren, ob das actually so funktioniert - ist zwar ziemlich lange her, aber ich glaube das lange Text immer abgeschnitten wurden
class InfoDialogEntry extends StatelessWidget {
  final String text;
  final IconData icon;
  final EdgeInsets? paddingTop;
  const InfoDialogEntry({super.key, required this.icon, required this.text, this.paddingTop});

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: paddingTop ?? const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          Flexible(child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(text, maxLines: 10),
          )),
        ],
      ),
    );
    return Flexible(
      child: child
    );
  }
}
