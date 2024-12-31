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
import 'package:kepler_app/tabs/lernsax/pages/mails_page.dart';
import 'package:provider/provider.dart';

/// Widget, was eine Liste der aktuellen LS-Mails aus dem Posteingang anzeigt
class HomeLSMailsWidget extends StatefulWidget {
  /// Home-Widget-ID - muss mit der in home.dart übereinstimmen
  final String id;

  const HomeLSMailsWidget({super.key, required this.id});

  @override
  State<HomeLSMailsWidget> createState() => _HomeLSMailsWidgetState();
}

class _HomeLSMailsWidgetState extends State<HomeLSMailsWidget> {
  bool loading = true;
  String? folderId;
  List<LSMailListing>? mailsSlice;

  @override
  Widget build(BuildContext context) {
    return HomeWidgetBase(
      id: widget.id,
      color: hasDarkTheme(context) ? colorWithLightness(const Color.fromARGB(255, 46, 129, 25), .1) : Colors.green.shade300,
      title: const Text("LernSax: E-Mails"),
      /// da LSMailTile für die Anhänge-Anzeige die Login-Daten braucht (um den richtigen Account zu nehmen),
      /// muss hier ein Consumer eingefügt werden (obwohl die Daten durch den Listener bei Änderungen an
      /// CredentialStore eh neu geladen werden)
      child: Consumer<CredentialStore>(
        builder: (context, creds, _) {
          if (loading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Lädt..."),
              ),
            );
          }
          if (folderId == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Fehler beim Laden der Ordner."),
              ),
            );
          }
          if (mailsSlice == null || creds.lernSaxLogin == null || creds.lernSaxToken == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Fehler beim Laden der Mails."),
              ),
            );
          }
          if (mailsSlice!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Keine E-Mails im Posteingang."),
              ),
            );
          }
          return Column(
            children: separatedListViewWithDividers(
              mailsSlice!.map<Widget>((data) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: LSMailTile(
                  mail: data,
                  folderId: folderId!,
                  darkerIcons: !hasDarkTheme(context),
                  onAfterSuccessfulMailAction: loadData,
                  login: creds.lernSaxLogin!,
                  token: creds.lernSaxToken!,
                  alternative: false,
                ),
              )).toList()
                ..add(
                  ListTile(
                    title: const Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text("Alle Mails"),
                        ),
                        Icon(Icons.open_in_new, size: 20),
                      ],
                    ),
                    onTap: () {
                      final navId = [LernSaxPageIDs.main];
                      final lsEntry = destinations.firstWhere((e) => e.id == LernSaxPageIDs.main);
                      final lsChildren = lsEntry.getChildren(context);
                      if (lsChildren.first.id.startsWith(kLernSaxUserNavPrefix)) navId.add(lsChildren.first.id);
                      navId.add(LernSaxPageIDs.emails);
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
    /// wenn der Benutzer sich neu anmelden will, wird dieses Widget auf der Startseite gerendert
    /// - um dann nach der Anmeldung automatisch die Daten zu laden, wird auf Änderungen in CredentialStore reagiert
    /// 
    /// das sorgt zwar aktuell für einen unsichtbaren Null-Fehler (bei creds.lernSaxLogin!), nachdem sich der Nutzer
    /// abgemeldet hat - ist aber egal, da es dann beim Anmelden wieder geht
    Provider.of<CredentialStore>(context, listen: false).addListener(loadData);
    loadData();
  }

  /// eigentlich wie in tabs/lernsax/pages/mails_page.dart, aber nur für Hauptaccount
  Future<void> loadData() async {
    setState(() {
      loading = true;
    });
    final creds = Provider.of<CredentialStore>(context, listen: false);

    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    if (lsdata.mailFolders == null) {
      final (online, mailFolders) = await lernsax.getMailFolders(creds.lernSaxLogin!, creds.lernSaxToken!);
      if (online && mailFolders != null) {
        lsdata.mailFolders = mailFolders;
      }
    }
    final inbox = lsdata.mailFolders?.firstWhere((fl) => fl.isInbox);
    if (inbox == null) {
      setState(() {
        loading = false;
      });
      return;
    }
    final mails = lsdata.mailListings?.where((ls) => ls.folderId == inbox.id).toList();
    mailsSlice = mails?.sublist(0, min(3, mails.length));

    if (mailsSlice?.isEmpty ?? true) {
      final (online, mailLsts) = await lernsax.getMailListings(creds.lernSaxLogin!, creds.lernSaxToken!, folderId: inbox.id);
      if (!online || mailLsts == null) {
        mailsSlice = null;
        return;
      }
      mailLsts.sort((a, b) => b.date.compareTo(a.date));
      // Provider.of<LernSaxData>(context, listen: false).tasks = tasks;
      mailsSlice = mailLsts.sublist(0, min(3, mailLsts.length));
    }

    if (!mounted) return;
    setState(() {
      loading = false;
      folderId = inbox.id;
    });
  }

  @override
  void dispose() {
    // i have to use the global context here because the widget context is already marked as deactivated
    Provider.of<CredentialStore>(globalScaffoldContext, listen: false).removeListener(loadData);
    super.dispose();
  }
}
