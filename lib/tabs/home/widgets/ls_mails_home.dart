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

class HomeLSMailsWidget extends StatefulWidget {
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
      color: hasDarkTheme(context) ? colorWithLightness(Color.fromARGB(255, 46, 129, 25), .1) : Colors.green,
      title: const Text("LernSax: E-Mails"),
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
          if (folderId == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Fehler beim Laden der Ordner."),
              ),
            );
          }
          if (mailsSlice == null) {
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
                child: LSMailTile(mail: data, folderId: folderId!),
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
                      Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [
                        LernSaxPageIDs.main,
                        LernSaxPageIDs.tasks,
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

    final lsdata = Provider.of<LernSaxData>(context, listen: false);
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
      // this only loads tasks from the user themselves, because i don't want to bother loading all tasks just for this widget
      // all widgets will be considered if the users opens the task page
      final creds = Provider.of<CredentialStore>(context, listen: false);
      final (online, mailLsts) = await lernsax.getMailListings(creds.lernSaxLogin!, creds.lernSaxToken!, folderId: inbox.id);
      if (!online || mailLsts == null) {
        mailsSlice = null;
        return;
      }
      mailLsts.sort((a, b) => b.date.compareTo(a.date));
      // Provider.of<LernSaxData>(context, listen: false).tasks = tasks;
      mailsSlice = mailLsts.sublist(0, min(3, mailLsts.length));
    }

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
