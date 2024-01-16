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
      color: hasDarkTheme(context) ? colorWithLightness(const Color.fromARGB(255, 46, 129, 25), .1) : Colors.green.shade300,
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
                child: LSMailTile(mail: data, folderId: folderId!, darkerIcons: !hasDarkTheme(context)),
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
                        LernSaxPageIDs.emails,
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
      final (online, mailLsts) = await lernsax.getMailListings(creds.lernSaxLogin!, creds.lernSaxToken ?? "", folderId: inbox.id);
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
