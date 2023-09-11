import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/lernsax/pages/notifs_page.dart';
import 'package:kepler_app/tabs/lernsax/pages/tasks_page.dart';
import 'package:provider/provider.dart';

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
        if (creds.lernSaxToken == null) return const Center(child: Text("Fehler: Nicht mit LernSax angemeldet."));
        final navPage = state.selectedNavPageIDs.last;
        if (navPage == LernSaxPageIDs.notifications) return LSNotificationPage();
        if (navPage == LernSaxPageIDs.tasks) return const LSTasksPage();
        return const Text("Unbekannte Seite gefordert. Bitte schließen und erneut probieren.");
      },
    );
  }
}
