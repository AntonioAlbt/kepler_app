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

import 'package:flutter/material.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:provider/provider.dart';

/// Dialog, um LernSax-Mitglieder aus Institution zu suchen und beliebig viele auszuwählen
/// 
/// hier wird nichts gecached, bei jedem Öffnen des Dialoges wird also eine neue API-Anfrage
/// nach allen Mitgliedern geschickt
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
          Expanded(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height * .5,
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
    final creds = Provider.of<CredentialStore>(context, listen: false);
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
