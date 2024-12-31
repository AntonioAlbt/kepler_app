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

/// wie LSMailsWidget, aber für Benachrichtigungen
class HomeLSNotifsWidget extends StatefulWidget {
  /// Home-Widget-ID - muss mit der in home.dart übereinstimmen
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
      color: hasDarkTheme(context) ? colorWithLightness(const Color.fromARGB(255, 13, 126, 83), .1) : Colors.teal.shade200,
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
              /// geladene Benachrichtigungen und Link zur LS-Notifs-Seite anzeigen
              notifsSlice!.map<Widget>((data) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: LSNotificationTile(notif: data, darkerClock: !hasDarkTheme(context)),
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
                      final navId = [LernSaxPageIDs.main];
                      final lsEntry = destinations.firstWhere((e) => e.id == LernSaxPageIDs.main);
                      final lsChildren = lsEntry.getChildren(context);
                      if (lsChildren.first.id.startsWith(kLernSaxUserNavPrefix)) navId.add(lsChildren.first.id);
                      navId.add(LernSaxPageIDs.notifications);
                      Provider.of<AppState>(context, listen: false).selectedNavPageIDs = navId;
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
    /// siehe HomeLSMailsWidget.initState
    Provider.of<CredentialStore>(context, listen: false).addListener(loadData);
    loadData();
  }

  /// wie in tabs/lernsax/pages/notifs_page.dart, aber nur für Hauptaccount
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
      notifs.sort((a, b) => a.date.compareTo(b.date));
      if (!mounted) return;
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
