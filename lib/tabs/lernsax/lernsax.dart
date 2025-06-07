// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2023-2025 Antonio Albert

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

import 'dart:convert';
import 'dart:io';

import 'package:appcheck/appcheck.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/lernsax/pages/files_page.dart';
import 'package:kepler_app/tabs/lernsax/pages/mails_page.dart';
import 'package:kepler_app/tabs/lernsax/pages/notifs_page.dart';
import 'package:kepler_app/tabs/lernsax/pages/tasks_page.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// nicht zu verwechseln mit lernsax.dart in lib/

/// Hauptseite für alle LernSax-Seiten, kümmert sich um Erkennung, auf welches Konto zugegriffen werden soll
class LernSaxTab extends StatefulWidget {
  const LernSaxTab({super.key});

  @override
  State<LernSaxTab> createState() => _LernSaxTabState();
}

class _LernSaxTabState extends State<LernSaxTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AppState, CredentialStore>(
      builder: (context, state, creds, _) {
        /// "entschlüssele" LS-Login aus Navigationspfad - Schema: "<kLernSaxUserNavPrefix>:<base64url(login)>"
        final navpid = state.selectedNavPageIDs[1];
        final login = navpid.startsWith(kLernSaxUserNavPrefix) ? utf8.decode(base64Url.decode(navpid.substring(kLernSaxUserNavPrefix.length))) : creds.lernSaxLogin;
        final token = login == creds.lernSaxLogin ? creds.lernSaxToken : creds.alternativeLSTokens[creds.alternativeLSLogins.indexOf(login ?? "")];
        if (token == null || login == null) return const Center(child: Text("Fehler: Nicht mit LernSax angemeldet."));
        final navPage = state.selectedNavPageIDs.last;
        final alternative = token != creds.lernSaxToken;
        if (navPage == LernSaxPageIDs.notifications) return LSNotificationPage(login, token, alternative);
        if (navPage == LernSaxPageIDs.tasks) return LSTasksPage(login, token, alternative);
        if (navPage == LernSaxPageIDs.emails) return LSMailsPage(login, token, alternative);
        if (navPage == LernSaxPageIDs.files) return LSFilesPage(login, token, alternative, key: lsFoldersPageKey);
        // if (navPage == LernSaxPageIDs.main) return const LSHomePage();
        return const Text("Unbekannte Seite gefordert. Bitte schließen und erneut probieren.");
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final istate = Provider.of<InternalState>(context, listen: false);
      final creds = Provider.of<CredentialStore>(context, listen: false);
      final sie = Provider.of<Preferences>(context, listen: false).preferredPronoun == Pronoun.sie;

      final state = Provider.of<AppState>(context, listen: false);
      final navpid = state.selectedNavPageIDs[1];
      final login = navpid.startsWith("lslogin:") ? utf8.decode(base64Url.decode(navpid.substring(8))) : creds.lernSaxLogin;
      final token = login == creds.lernSaxLogin ? creds.lernSaxToken : creds.alternativeLSTokens[creds.alternativeLSLogins.indexOf(login ?? "")];
      if (token == null || login == null) return;

      /// hilfreicherweise den Benutzer darauf hinweisen, wenn er keine Push-Nachrichten oder nicht
      /// für alle Klassen/Gruppen überhaupt Benachrichtigungen aktiviert hat
      /// (aber über die API scheint sich das nicht ändern zu lassen, also nur auf den Browser verweisen)
      () async {
        if (!istate.infosShown.contains("ls_notif_info")) {
          final (online, data) = await getNotificationSettings(login, token);
          if (!online || data == null) return;

          if (data.where((d) => d.enabledFacilities.contains("push")).length < data.length) {
            showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("LernSax: Hinweis"),
                content: Text(
                  "${sie ? "Sie haben" : "Du hast"} bei LernSax nicht für alle Infos Benachrichtigungen aktiviert. "
                  "Das bedeutet, dass ${sie ? "Sie" : "Du"} nicht alle Infos über die App ${sie ? "erhalten" : "erhältst"}.",
                ),
                actions: [
                  TextButton(onPressed: () {
                    istate.addInfoShown("ls_notif_info");
                    Navigator.pop(ctx, false);
                  }, child: const Text("Ignorieren")),
                  TextButton(onPressed: () {
                    showSnackBar(text: "Passt an...", duration: const Duration(seconds: 10), clear: true);
                    setNotificationSettings(creds.lernSaxLogin!, creds.lernSaxToken!, data: data.map((d) {
                      if (!d.enabledFacilities.contains("push")) d.enabledFacilities.add("push");
                      return d;
                    }).toList()).then((value) {
                      if (value.$2) {
                        showSnackBar(text: "Erfolgreich.", clear: true);
                      } else {
                        showSnackBar(text: "Fehler beim Ändern der Benachrichtigungen.", clear: true);
                      }
                    });
                    Navigator.pop(ctx, true);
                  }, child: const Text("Anpassen")),
                ],
              ),
            ).then((confirmed) {
              if (confirmed != true) return null; // confirmed = false or null
              if (!mounted) return null;
              return showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Info"),
                  content: Text(
                    "Wir können nicht überprüfen, ob ${sie ? "Sie" : "Du"} für alle Klassen oder Gruppen Benachrichtigungen aktiviert ${sie ? "haben" : "hast"}.\n"
                    "${sie ? "Sie können" : "Du kannst"} dies im Browser aber selbst überprüfen.",
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
                    TextButton(onPressed: () {
                      lernSaxOpenInBrowser(context, login, token);
                      Navigator.pop(ctx);
                    }, child: const Text("Im Browser öffnen")),
                  ],
                ),
              );
            }).then((_) => istate.infosShown.add("ls_notif_info"));
          }
        }
      }();
    });
  }
}

// currently unused
class LSHomePage extends StatelessWidget {
  const LSHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO - future: make available, maybe special overview
    return const Center(
      child: Text("Bald verfügbar."),
    );
  }
}

/// Widget, was darauf hinweist, dass man für die Verwendung eines alternativen Accounts online sein muss
class LSAltNoConnection extends StatelessWidget {
  final String login;
  const LSAltNoConnection({super.key, required this.login});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Keine Verbindung zu LernSax.", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text("Nur Daten für das primäre Konto werden lokal gespeichert, deshalb sind keine Daten für $login verfügbar.", textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

const lernSaxMsgrAndroidPkg = "de.digionline.lernsax";
const lernSaxMsgrAppleAppId = "1564415378";

const lernSaxAppInfoKey = "lern_sax_app_info_key";

/// offizielle App "LernSax Messenger" oder deren Seite im App/Play Store öffnen
Future<bool> lernSaxOpenInOfficialApp(BuildContext context) async {
  final internal = Provider.of<InternalState>(context, listen: false);
  // internal.infosShown = internal.infosShown..clear();
  if (!internal.infosShown.contains(lernSaxAppInfoKey)) {
    final sie = Provider.of<Preferences>(context, listen: false).preferredPronoun == Pronoun.sie;
    bool appInstalled = false;
    try {
      await AppCheck().checkAvailability(lernSaxMsgrAndroidPkg);
      appInstalled = true; // will only ever happen on android because the checker only works for android
    } catch (_) {}
    // ignore: use_build_context_synchronously
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Info zum Vertretungsplan"),
      content: Text.rich(TextSpan(
          style: const TextStyle(fontSize: 16),
          children: [
            TextSpan(text: "${sie ? "Ihre" : "Deine"} Dateien, E-Mails und Chats werden in der offiziellen LernSax-App (Messenger) geöffnet.${!appInstalled ? " Da diese nicht installiert ist, ${sie ? "werden Sie" : "wirst Du"} jetzt in den Play Store weitergeleitet." : ""}\n"),
            if (Platform.isIOS) TextSpan(text: "Leider kann auf iOS die App nicht direkt geöffnet werden, also ${sie ? "werden Sie" : "wirst Du"} zum App Store weitergeleitet.\n"),
            const TextSpan(text: "\nDiese Info wird nur einmalig angezeigt."),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("OK"),
        ),
      ],
    ));
    internal.addInfoShown(lernSaxAppInfoKey);
  }

  if (Platform.isAndroid) {
    try {
      await AppCheck().launchApp(lernSaxMsgrAndroidPkg);
    } catch (_) {
      try {
        await launchUrl(Uri.parse("market://details?id=$lernSaxMsgrAndroidPkg"));
      } catch (_) {
        showSnackBar(text: "Keine App zum Installieren von Apps gefunden.", error: true);
      }
    }
  } else if (Platform.isIOS) {
    launchUrl(Uri.parse("https://apps.apple.com/de/app/id$lernSaxMsgrAppleAppId"), mode: LaunchMode.externalApplication);
  }
  return false;
}

/// LernSax angemeldet im Browser öffnen
Future<bool> lernSaxOpenInBrowser(BuildContext context, String login, String token) async {
  final creds = Provider.of<CredentialStore>(context, listen: false);
  if (creds.lernSaxToken == null || creds.lernSaxLogin == null) return false;
  final (online, url) = await getSingleUseLoginLink(login, token);
  if (!online) {
    showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
  } else if (url == null) {
    showSnackBar(text: "Fehler beim Erstellen des Links.", error: true);
  } else {
    launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }
  return false;
}
