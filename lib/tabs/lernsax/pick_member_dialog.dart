import 'package:flutter/material.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:provider/provider.dart';

class LSPickMemberDialog extends StatefulWidget {
  const LSPickMemberDialog({super.key});

  @override
  State<LSPickMemberDialog> createState() => _LSPickMemberDialogState();
}

class _LSPickMemberDialogState extends State<LSPickMemberDialog> {
  bool _loading = true;
  late List<LSMailAddressable> data;
  late TextEditingController _searchController;
  String _searchText = "";
  String error = "";
  late List<String> selectedMails;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: _loading ? const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text("Lädt Mitglieder..."),
          ),
        ],
      ) : (error != "") ? Text(error) : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "Suche hier eingeben...",
                ),
              ),
            ),
          ),
          SizedBox(
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height * .5,
            // child: ListView.builder(
            //   itemBuilder: (context, i) => CheckboxListTile(
            //     value: selectedMails.contains(data[i].address),
            //     onChanged: (select) {
            //       if (select == true) {
            //         setState(() => selectedMails.add(data[i].address));
            //       } else {
            //         setState(() => selectedMails.remove(data[i].address));
            //       }
            //     },
            //     title: Text(data[i].name),
            //     subtitle: Text(data[i].address),
            //   ),
            //   itemCount: data.length,
            // ),
            child: ListView(
              children: data.where((element) => _searchText == "" || element.address.toLowerCase().startsWith(_searchText.toLowerCase()) || element.name.toLowerCase().startsWith(_searchText.toLowerCase())).map((d) => CheckboxListTile(
                value: selectedMails.contains(d.address),
                onChanged: (select) {
                  if (select == true) {
                    setState(() => selectedMails.add(d.address));
                  } else {
                    setState(() => selectedMails.remove(d.address));
                  }
                },
                title: Text(d.name),
                subtitle: Text(d.address),
              )).toList(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Divider(),
          ),
          Text(
            "Ausgewählte Empfänger:${selectedMails.isEmpty ? " keine" : selectedMails.length > 3 ? "\n${selectedMails.length} E-Mails gewählt" : " ${selectedMails.join(", ")}"}",
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: _loading ? null : error != "" ? [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
      ] : [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
        TextButton(onPressed: () => Navigator.pop(context, selectedMails), child: const Text("Hinzufügen")),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    data = [];
    selectedMails = [];
    _searchController = TextEditingController();
    _searchController.addListener(() => setState(() => _searchText = _searchController.text));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final creds = Provider.of<CredentialStore>(globalScaffoldContext, listen: false);
    final (online, users) = await getAllUsersInSchool(creds.lernSaxLogin!, creds.lernSaxToken!);
    if (!online) {
      error = "Fehler beim Abfragen der Benutzer: Es konnte keine Verbindung zu den LernSax-Servern hergestellt werden.";
    } else if (users == null) {
      error = "Fehler beim Abfragen der Benutzer von LernSax.";
    } else {
      data = users;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
