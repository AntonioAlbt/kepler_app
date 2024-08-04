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

import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/libs/custom_simple_chips_input.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/lernsax/pick_member_dialog.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

Widget mailWritePageBuilder(BuildContext context) => const MailWritePage();

enum LSMWPReferenceMode {
  forwarded, answered, draftToDelete;

  LSMailReferenceMode? convert() => {
    LSMWPReferenceMode.answered: LSMailReferenceMode.answered,
    LSMWPReferenceMode.forwarded: LSMailReferenceMode.forwarded,
  }[this];
}

class MailWritePage extends StatefulWidget {
  final List<String>? to;
  final String? subject;
  final String? mail;
  final LSMail? reference;
  final LSMWPReferenceMode? referenceMode;

  const MailWritePage({super.key, this.to, this.subject, this.mail, this.reference, this.referenceMode});

  @override
  State<MailWritePage> createState() => _MailWritePageState();
}

final mailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$");

class _MailWritePageState extends State<MailWritePage> {
  final recvKey = GlobalKey<SimpleChipsInputState>();
  final _mailScrollCtrl = ScrollController();
  final _sciCtrl = SimpleChipsInputController();
  final _mailInputCtrl = TextEditingController();
  final _subjectInputCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (popped) async {
        if (popped) return;
        if (_mailInputCtrl.text != (widget.mail ?? "") ||
            _subjectInputCtrl.text != (widget.subject ?? "") ||
            recvKey.currentState!.chips.join("|") != (widget.to ?? []).join("|")) {
          final sie = Provider.of<Preferences>(globalScaffoldContext, listen: false).preferredPronoun == Pronoun.sie;
          await showDialog(context: globalScaffoldContext, builder: (ctx) => AlertDialog(
            title: const Text("Eingaben verwerfen?"),
            content: Text("${sie ? "Wollen Sie Ihre" : "Willst Du Deine"} Eingaben verwerfen? ${sie ? "Ihre" : "Deine"} Änderungen werden damit nicht gespeichert."),
            actions: [
              TextButton(onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }, child: const Text("Verwerfen")),
              TextButton(onPressed: () {
                Navigator.pop(ctx);
              }, child: const Text("Weiter bearbeiten")),
            ],
          ));
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("E-Mail verfassen")),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(MdiIcons.inboxArrowUp),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) => Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: "von: ",
                          ),
                          TextSpan(
                            text: "${Provider.of<CredentialStore>(globalScaffoldContext).lernSaxLogin}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            KeyboardVisibilityBuilder(
              builder: (context, visible) {
                return AnimatedSize(
                  duration: const Duration(milliseconds: 100),
                  child: Align(
                    child: SimpleChipsInput(
                      key: recvKey,
                      controller: _sciCtrl,
                      separatorCharacter: "|",
                      createCharacter: ",",
                      textFormFieldStyle: const TextFormFieldStyle(
                        decoration: InputDecoration(
                          hintText: "Empfänger, getrennt durch Kommas",
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      deleteIcon: const Padding(
                        padding: EdgeInsets.only(left: 2),
                        child: Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                      validateInput: true,
                      validateInputMethod: (input) => mailRegex.hasMatch(input) ? null : "Ungültige Email.",
                      leadingChips: const [
                        Text("an: "),
                      ],
                      chipIfEmpty: const Text("keine Empfänger hinzugefügt"),
                      trailingChips: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final toAdd = await showDialog<List<String>>(
                              context: context,
                              builder: (ctx) => const LSPickMemberDialog(),
                            );
                            if (toAdd == null) return;
                            
                            final list = recvKey.currentState!.chips;
                            final newList = [...{...list, ...toAdd}];
                            recvKey.currentState!.chips.clear();
                            recvKey.currentState!.chips.addAll(newList);
                            setState(() {});
                          },
                          label: const Text("Von LernSax hinzufügen"),
                          icon: const Icon(Icons.mail, size: 18),
                        ),
                      ],
                      icon: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(MdiIcons.inboxArrowDown),
                          ),
                        ),
                      ),
                      maxHeight: MediaQuery.sizeOf(context).height * (visible ? .1 : .2),
                    ),
                  ),
                );
              }
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
              child: TextFormField(
                controller: _subjectInputCtrl,
                decoration: const InputDecoration(
                  hintText: "Betreff",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Scrollbar(
                  controller: _mailScrollCtrl,
                  child: TextFormField(
                    controller: _mailInputCtrl,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    expands: true,
                    // minLines: 4,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Inhalt der E-Mail",
                    ),
                    scrollController: _mailScrollCtrl,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      _sciCtrl.doTrySubmit();
                      if (_subjectInputCtrl.text == "") {
                        showSnackBar(text: "E-Mail hat keinen Betreff!", error: true);
                        return;
                      }
                      final creds = Provider.of<CredentialStore>(globalScaffoldContext, listen: false);
                      if (creds.lernSaxLogin == lernSaxDemoModeMail) {
                        await showDialog(context: context, builder: (ctx) => AlertDialog(
                          title: const Text("Nicht möglich."),
                          content: const Text("Im Demo-Modus können keine E-Mails gespeichert werden."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
                          ],
                        ));
                        return;
                      }
        
                      final (online, success) = await saveDraft(
                        creds.lernSaxLogin!,
                        creds.lernSaxToken!,
                        subject: _subjectInputCtrl.text,
                        to: recvKey.currentState!.chips,
                        bodyPlain: _mailInputCtrl.text,
                      );
        
                      if (!online) return showSnackBar(text: "LernSax ist nicht erreichbar. E-Mail konnte nicht gespeichert werden.", error: true);
                      if (!success) return showSnackBar(text: "Fehler beim Speichern der E-Mail.", error: true);
      
                      if (widget.reference != null && widget.referenceMode == LSMWPReferenceMode.draftToDelete) {
                        await deleteMail(
                          creds.lernSaxLogin!,
                          creds.lernSaxToken!,
                          folderId: widget.reference!.folderId,
                          mailId: widget.reference!.id,
                        );
                        showSnackBar(text: "Entwurf erfolgreich aktualisiert.");
                      } else {
                        showSnackBar(text: "Neuen Entwurf gespeichert.");
                      }
                      
                      if (mounted) Navigator.pop(this.context);
                    },
                    icon: const Icon(Icons.archive),
                    label: const Text("Entwurf speichern"),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      _sciCtrl.doTrySubmit();
                      if (recvKey.currentState!.chips.isEmpty) {
                        showSnackBar(text: "Keine Empfänger ausgewählt!", error: true);
                        return;
                      }
                      if (_subjectInputCtrl.text == "") {
                        showSnackBar(text: "E-Mail hat keinen Betreff!", error: true);
                        return;
                      }
                      final creds = Provider.of<CredentialStore>(globalScaffoldContext, listen: false);
                      if (creds.lernSaxLogin == lernSaxDemoModeMail) {
                        await showDialog(context: context, builder: (ctx) => AlertDialog(
                          title: const Text("Nicht möglich."),
                          content: const Text("Im Demo-Modus können keine E-Mails versendet werden."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
                          ],
                        ));
                        return;
                      }
                      if (!await showDialog(context: context, builder: (ctx) => AlertDialog(
                        title: const Text("Wirklich absenden?"),
                        content: Builder(builder: (_) => Text("${Provider.of<Preferences>(globalScaffoldContext).preferredPronoun == Pronoun.sie ? "Wollen Sie" : "Willst Du"} diese E-Mail wirklich so an ${joinWithOptions(recvKey.currentState!.chips, ", ", " und ")} abschicken?")),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Ja, jetzt senden")),
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Abbrechen")),
                        ],
                      ))) return;
        
                      final (online, success) = await sendMail(
                        creds.lernSaxLogin!,
                        creds.lernSaxToken!,
                        subject: _subjectInputCtrl.text,
                        to: recvKey.currentState!.chips,
                        text: _mailInputCtrl.text,
                        referenceMsgId: widget.reference?.id,
                        referenceMsgFolderId: widget.reference?.folderId,
                        referenceMode: widget.referenceMode?.convert(),
                      );
        
                      if (!online) return showSnackBar(text: "LernSax ist nicht erreichbar. E-Mail konnte nicht versendet werden.", error: true);
                      if (!success) return showSnackBar(text: "Fehler beim Versenden der E-Mail.", error: true);

                      showSnackBar(text: "E-Mail erfolgreich versendet.");
                      
                      if (mounted && success) Navigator.pop(this.context);
                    },
                    icon: const Icon(Icons.send, size: 20),
                    label: const Text("Absenden"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    if (widget.to != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        recvKey.currentState!.chips.addAll(widget.to!);
        setState(() {});
      });
    }
    if (widget.subject != null) _subjectInputCtrl.text = widget.subject!;
    if (widget.mail != null) _mailInputCtrl.text = widget.mail!;
    super.initState();
  }

  @override
  void dispose() {
    _mailScrollCtrl.dispose();
    super.dispose();
  }
}
