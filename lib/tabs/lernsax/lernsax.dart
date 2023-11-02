import 'dart:io';

import 'package:appcheck/appcheck.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/lernsax/pages/mails_page.dart';
import 'package:kepler_app/tabs/lernsax/pages/notifs_page.dart';
import 'package:kepler_app/tabs/lernsax/pages/tasks_page.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
        if (creds.lernSaxToken == null || creds.lernSaxLogin == null) return const Center(child: Text("Fehler: Nicht mit LernSax angemeldet."));
        final navPage = state.selectedNavPageIDs.last;
        if (navPage == LernSaxPageIDs.notifications) return LSNotificationPage();
        if (navPage == LernSaxPageIDs.tasks) return LSTasksPage();
        if (navPage == LernSaxPageIDs.emails) return LSMailsPage();
        if (navPage == LernSaxPageIDs.main) return const LSHomePage();
        return const Text("Unbekannte Seite gefordert. Bitte schließen und erneut probieren.");
      },
    );
  }
}

class LSHomePage extends StatelessWidget {
  const LSHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text("Bald verfügbar."),
    );
  }
}

const lernSaxMsgrAndroidPkg = "de.digionline.lernsax";
const lernSaxMsgrAppleAppId = "1564415378";

const lernSaxAppInfoKey = "lern_sax_app_info_key";

Future<bool> lernSaxOpenInOfficialApp(BuildContext context) async {
  final internal = Provider.of<InternalState>(context, listen: false);
  // internal.infosShown = internal.infosShown..clear();
  if (!internal.infosShown.contains(lernSaxAppInfoKey)) {
    final sie = Provider.of<Preferences>(context, listen: false).preferredPronoun == Pronoun.sie;
    bool appInstalled = false;
    try {
      await AppCheck.checkAvailability(lernSaxMsgrAndroidPkg);
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
      await AppCheck.launchApp(lernSaxMsgrAndroidPkg);
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

Future<bool> lernSaxOpenInBrowser(context) async {
  final creds = Provider.of<CredentialStore>(context, listen: false);
  if (creds.lernSaxToken == null || creds.lernSaxLogin == null) return false;
  final (online, url) = await getSingleUseLoginLink(creds.lernSaxLogin!, creds.lernSaxToken!);
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
