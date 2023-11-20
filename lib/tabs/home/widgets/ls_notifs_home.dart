import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/widgets.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/lernsax/pages/notifs_page.dart';
import 'package:provider/provider.dart';

class HomeLSNotifsWidget extends StatefulWidget {
  final String id;

  const HomeLSNotifsWidget({super.key, required this.id});

  @override
  State<HomeLSNotifsWidget> createState() => _HomeLSNotifsWidgetState();
}

class _HomeLSNotifsWidgetState extends State<HomeLSNotifsWidget> {
  bool loading = true;
  List<LSNotification>? notifsSlice;

  @override
  Widget build(BuildContext context) {
    return HomeWidgetBase(
      id: widget.id,
      color: hasDarkTheme(context) ? colorWithLightness(const Color.fromARGB(255, 13, 126, 83), .1) : Colors.teal,
      title: const Text("LernSax: Benachrichtigungen"),
      titleColor: Theme.of(context).cardTheme.surfaceTintColor,
      child: Builder(
        builder: (context) {
          if (loading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Lädt..."),
              ),
            );
          }
          if (notifsSlice == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Fehler beim Laden."),
              ),
            );
          }
          if (notifsSlice!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Keine Benachrichtigungen."),
              ),
            );
          }
          return Column(
            children: separatedListViewWithDividers(
              notifsSlice!.map<Widget>((data) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: LSNotificationTile(notif: data),
              )).toList()
                ..add(
                  ListTile(
                    title: const Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text("Alle Benachrichtigungen"),
                        ),
                        Icon(Icons.open_in_new, size: 20),
                      ],
                    ),
                    onTap: () {
                      Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [
                        LernSaxPageIDs.main,
                        LernSaxPageIDs.notifications
                      ];
                    },
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  ),
                ),
            ),
          );
        }
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Provider.of<CredentialStore>(context, listen: false).addListener(loadData);
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
    });

    final notifs = Provider.of<LernSaxData>(context, listen: false).notifications ?? [];
    notifsSlice = notifs.sublist(0, min(3, notifs.length));

    if (notifsSlice!.isEmpty) {
      final creds = Provider.of<CredentialStore>(context, listen: false);
      final (online, notifs) = await lernsax.getNotifications(creds.lernSaxLogin!, creds.lernSaxToken!);
      if (!online || notifs == null) {
        notifsSlice = null;
        return;
      }
      Provider.of<LernSaxData>(context, listen: false).notifications = notifs;
      notifsSlice = notifs.sublist(0, min(3, notifs.length));
    }

    setState(() {
      loading = false;
    });
  }

  @override
  void dispose() {
    // i have to use the global context here because the widget context is already marked as deactivated
    Provider.of<CredentialStore>(globalScaffoldContext, listen: false).removeListener(loadData);
    super.dispose();
  }
}
