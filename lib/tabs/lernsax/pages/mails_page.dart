import 'package:flutter/material.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:provider/provider.dart';

final lsMailPageKey = GlobalKey<_LSMailsPageState>();

void lernSaxMailsRefreshAction() {
  lsMailPageKey.currentState?.loadData();
}

class LSMailsPage extends StatefulWidget {
  LSMailsPage() : super(key: lsMailPageKey);

  @override
  State<LSMailsPage> createState() => _LSMailsPageState();
}

class _LSMailsPageState extends State<LSMailsPage> {
  bool _loadingFolders = false;
  String? selectedFolderId;
  
  @override
  Widget build(BuildContext context) {
    if (_loadingFolders) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Consumer<LernSaxData>(
      builder: (context, lsdata, child) {
        if (lsdata.memberships == null) {
          return Center(
            child: Column(
              children: [
                const Text(
                  "Fehler beim Abfragen. Ist Internet vorhanden?",
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ElevatedButton(
                    onPressed: loadData,
                    child: const Text("Erneut versuchen"),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            SizedBox(
              height: 50,
              child: AppBar(
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                elevation: 5,
                bottom: PreferredSize(
                  preferredSize: const Size(100, 50),
                  child: DropdownButton<String>(
                    items: lsdata.mailFolders?.map((e) => DropdownMenuItem<String>(value: e.id, child: Text(e.name))).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => selectedFolderId = val);
                      Provider.of<InternalState>(context, listen: false).lastSelectedLSMailFolder = val;
                    },
                    value: selectedFolderId,
                  ),
                ),
              ),
            ),
            Flexible(
              child: (selectedFolderId != null) ? LSMailDisplay(selectedFolderId: selectedFolderId!, key: ValueKey(selectedFolderId)) : const Text("..."),
            ),
          ],
        );
      }
    );
  }

  @override
  void initState() {
    selectedFolderId = Provider.of<InternalState>(context, listen: false).lastSelectedLSMailFolder ?? "";
    loadData();
    super.initState();
  }

  Future<void> loadData() async {
    setState(() => _loadingFolders = true);
    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final folders = await lernsax.getMailFolders(creds.lernSaxLogin!, creds.lernSaxToken!);
    if (folders == null) {
      showSnackBar(textGen: (sie) => "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} E-Mail-Ordner. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
      setState(() => _loadingFolders = false);
    } else {
      lsdata.mailFolders = folders;
      setState(() {
        _loadingFolders = false;
        if (selectedFolderId == "") selectedFolderId = folders.first.id;
      });
    }
  }
}

class LSMailDisplay extends StatefulWidget {
  final String selectedFolderId;

  const LSMailDisplay({super.key, required this.selectedFolderId});

  @override
  State<LSMailDisplay> createState() => _LSMailDisplayState();
}

class _LSMailDisplayState extends State<LSMailDisplay> {
  bool _loading = true;
  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
          ],
        ),
      );
    }
    return Consumer3<LernSaxData, InternalState, CredentialStore>(
      builder: (context, lsdata, istate, creds, _) {
        final mails = lsdata.mailListings?.where((e) => e.folderId == widget.selectedFolderId).toList();
        if (mails == null) {
          return const Center(
            child: Text(
              "E-Mails konnten nicht abgefragt werden.",
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          );
        }
        return Column(
          children: [
            if (mails.isEmpty) const Expanded(
              child: Center(
                child: Text(
                  "Keine E-Mails vorhanden.",
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            if (mails.isNotEmpty) Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: mails.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FutureBuilder(
                        future: lernsax.getMailState(creds.lernSaxLogin!, creds.lernSaxToken!),
                        builder: (context, datasn) {
                          if (datasn.connectionState == ConnectionState.waiting) {
                            return const Text("Lädt Status...");
                          }
                          final data = datasn.data;
                          if (data == null) return const Text("Daten zur Mailbox nicht verfügbar.");
                          return Text("${(data.usageBytes / 1024 / 1024).round()} MB belegt, ${(data.freeBytes / 1024 / 1024)} MB frei - ${data.unreadMessages} ungelesene E-Mails");
                        },
                      ),
                    );
                  }
                  final mail = mails[i - 1];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        textStyle: Theme.of(context).textTheme.bodyMedium,
                        foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      // onPressed: () => showDialog(context: context, builder: (ctx) => generateLernSaxNotifInfoDialog(ctx, notif)), // TODO: create generateLernSaxMailInfoDialog
                      onPressed: () {},
                      child: Column(
                        children: [
                          Text(mail.toString()),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, i) => const Divider(),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    loadTasksForSelectedClass();
    super.initState();
  }

  Future<void> loadTasksForSelectedClass() async {
    setState(() => _loading = true);
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    final data = await lernsax.getMailListings(creds.lernSaxLogin!, creds.lernSaxToken!, folderId: widget.selectedFolderId);
    if (data == null) {
      showSnackBar(textGen: (sie) =>  "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} E-Mails. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
    } else {
      lsdata.mailListings = data;
    }
    setState(() {
      _loading = false;
    });
  }
}
