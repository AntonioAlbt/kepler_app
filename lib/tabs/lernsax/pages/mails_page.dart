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
import 'package:intl/intl.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/rainbow.dart';
import 'package:kepler_app/tabs/lernsax/lernsax.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/lernsax/pages/mail_detail_page.dart';
import 'package:kepler_app/tabs/lernsax/pages/mail_write_page.dart';
import 'package:kepler_app/tabs/lernsax/pages/notifs_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

final lsMailPageKey = GlobalKey<_LSMailsPageState>();

void lernSaxMailsRefreshAction() {
  lsMailPageKey.currentState?.refreshData(force: true);
}

String _lastLoadedLogin = "";

/// Auflistungsseite für Mails, Ordner auswählbar und Mails können z.B. verschoben oder gelöscht werden
class LSMailsPage extends StatefulWidget {
  /// zu verwendender LS-Login
  final String login;
  /// zu verwendendes LS-Token
  final String token;
  /// wird nicht der primäre LS-Account verwendet?
  final bool alternative;

  LSMailsPage(this.login, this.token, this.alternative) : super(key: lsMailPageKey);

  @override
  State<LSMailsPage> createState() => _LSMailsPageState();
}

class _LSMailsPageState extends State<LSMailsPage> {
  bool _loadingFolders = false;
  String? selectedFolderId;
  final LSMailDispController dayDispController = LSMailDispController();
  var i = 0;

  String improveName(String oldName) {
    if (oldName == "INBOX") return "Posteingang";
    if (oldName == "SPAM") return "Spam";
    return oldName;
  }
  
  @override
  Widget build(BuildContext context) {
    // nötig, weil Flutter den State für das Widget nicht neu initialisiert, da der gleiche GlobalKey verwendet wird
    // (auch wenn sich die Argumente für den State ändern)
    if (_lastLoadedLogin != widget.login) {
      _lastLoadedLogin = widget.login;
      selectedFolderId = null;
      refreshData(force: true);
    }
    if (_loadingFolders) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Consumer<LernSaxData>(
      builder: (context, lsdata, child) {
        if (lsdata.mailFolders == null && !widget.alternative) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
            ),
          );
        }
        Widget main(List<LSMailFolder> mailFolders) => Column(
          children: [
            SizedBox(
              height: 50,
              child: AppBar(
                scrolledUnderElevation: 5,
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                elevation: 5,
                bottom: PreferredSize(
                  preferredSize: const Size(100, 50),
                  child: DropdownButton<String>(
                    items: lsdata.mailFolders?.map((e) => DropdownMenuItem<String>(value: e.id, child: Text(improveName(e.name)))).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => selectedFolderId = val);
                      Provider.of<InternalState>(context, listen: false).lastSelectedLSMailFolder = val;
                    },
                    value: selectedFolderId ?? mailFolders.first.id,
                  ),
                ),
              ),
            ),
            Flexible(
              child: (mailFolders.isNotEmpty)
                ? LSMailDisplay(
                    key: ValueKey(selectedFolderId ?? mailFolders.first.id),
                    selectedFolder: mailFolders.firstWhere((f) => f.id == (selectedFolderId ?? mailFolders.first.id)),
                    controller: dayDispController,
                    login: widget.login,
                    token: widget.token,
                    alternative: widget.alternative,
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child:
                          Text("Fehler beim Laden der Postfach-Ordner."),
                    ),
                  ),
            ),
          ],
        );
        /// bei alternativem Account keinen Cache verwenden
        if (widget.alternative) {
          return FutureBuilder(
            key: ValueKey(i),
            future: lernsax.getMailFolders(widget.login, widget.token),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              final (online, folders) = snapshot.data ?? (false, null);
              if (snapshot.hasError || folders == null || !online) {
                return LSAltNoConnection(login: widget.login);
              }
              i = 0;
              return main(folders);
            },
          );
        } else {
          return main(lsdata.mailFolders!);
        }
      }
    );
  }

  @override
  void initState() {
    refreshData();
    if (_lastLoadedLogin == "") _lastLoadedLogin = widget.login;
    super.initState();
  }
  
  Future<void> refreshData({ bool force = false }) async {
    if (widget.alternative) {
      setState(() => i++);
      return;
    }

    final folderIds = await loadData(force: force);
    // ignore: use_build_context_synchronously
    final prev = Provider.of<InternalState>(context, listen: false).lastSelectedLSMailFolder;
    if (prev != null && folderIds != null && folderIds.contains(prev)) {
      setState(() => selectedFolderId = prev);
    } else if (folderIds != null) {
      setState(() => selectedFolderId = folderIds.first);
    } else {
      setState(() => selectedFolderId = null);
    }
    dayDispController.onForceRefresh?.call();
  }

  Future<List<String>?> loadData({ bool force = false }) async {
    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    // only update mail folder data every 3 days because it doesn't change as often
    if (lsdata.lastMailFoldersUpdateDiff.inDays < 3 || force) return lsdata.mailFolders?.map((f) => f.id).toList();

    setState(() => _loadingFolders = true);
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final (online, folders) = await lernsax.getMailFolders(creds.lernSaxLogin!, creds.lernSaxToken!);
    if (!online) {
      showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
    } else if (folders == null) {
      showSnackBar(textGen: (sie) => "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} E-Mails-Postfächer. Bitte ${sie ? "probieren Sie" : "probiere"} es später erneut.", error: true, clear: true);
    } else {
      lsdata.mailFolders = folders;
      lsdata.lastMailFoldersUpdate = DateTime.now();
      // // don't setState here because I already tell flutter that I setState three lines from now
      // if (selectedFolderId == "") selectedFolderId = folders.first.id;
      showSnackBar(text: "E-Mails erfolgreich aktualisiert.", duration: const Duration(seconds: 1));
    }
    if (!mounted) return null;
    setState(() => _loadingFolders = false);
    return folders?.map((f) => f.id).toList();
  }
}

class LSMailDispController {
  void Function()? onForceRefresh;
}

/// Liste für die Emails im Ordner `selectedFolder`
class LSMailDisplay extends StatefulWidget {
  /// Ordner, der anzuzeigen ist
  final LSMailFolder selectedFolder;
  /// Controller, um aktualisieren auszulösen
  final LSMailDispController? controller;
  /// zu verwendender LS-Login
  final String login;
  /// zu verwendendes LS-Token
  final String token;
  /// wird nicht der primäre LS-Account verwendet?
  final bool alternative;

  const LSMailDisplay({super.key, required this.selectedFolder, this.controller, required this.login, required this.token, required this.alternative});

  @override
  State<LSMailDisplay> createState() => _LSMailDisplayState();
}

class _LSMailDisplayState extends State<LSMailDisplay> {
  bool _loading = true;
  (bool, LSMailState?)? mailData;
  List<LSMailListing>? mailListings;
  
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
    return Consumer2<InternalState, CredentialStore>(
      builder: (context, istate, creds, _) {
        final mails = mailListings?.where((e) => e.folderId == widget.selectedFolder.id).toList();
        if (mails == null) {
          if (widget.alternative) return LSAltNoConnection(login: widget.login);
          return const Center(
            child: Text(
              "E-Mails konnten nicht abgefragt werden.",
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          );
        }
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (ctx) => MailWritePage(
                preselectedAccount: creds.alternativeLSLogins.indexWhere((l) => l == widget.login) + 1,
              )));
            },
            icon: const Icon(Icons.edit_note),
            label: const Text("E-Mail verfassen"),
            heroTag: UniqueKey(),
          ),
          body: Column(
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
              if (mails.isNotEmpty) RainbowWrapper(
                builder: (context, color) {
                  return Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => widget.controller?.onForceRefresh?.call(),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: mails.length + 1,
                        /// unbedingt builder verwenden, da AttachmentAmountDisplay in LSMailTile beim Builden die Mail
                        /// herunterlädt, deshalb nicht alle auf einmal builden lassen!
                        itemBuilder: (context, i) {
                          /// erster Eintrag ist Info zu aktuellem Mail-Zustand
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Builder(
                                builder: (context) {
                                  final online = mailData?.$1 ?? false, data = mailData?.$2;
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                                    child: Column(
                                      children: [
                                        (mailData == null) ?
                                          const Column(
                                            children: [
                                              Text("Lädt Status..."),
                                              Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child: SizedBox(
                                                  height: 3,
                                                  width: 250,
                                                  child: LinearProgressIndicator(),
                                                ),
                                              ),
                                            ],
                                          )
                                        : (!online) ?
                                          const Text("Keine Verbindung zu LernSax möglich.")
                                        : (data == null) ?
                                          const Text("Fehler beim Laden der E-Mail-Daten.")
                                        : Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Row(
                                                children: [
                                                  Icon(MdiIcons.fileCabinet, size: 16, color: Colors.grey),
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 4),
                                                    child: Text("${(data.usageBytes / 1024 / 1024).round()} MB von ${(data.limitBytes / 1024 / 1024).round()} MB belegt (${(data.freeBytes / 1024 / 1024).round()} MB frei)"),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (widget.selectedFolder.isInbox) Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Row(
                                                children: [
                                                  Icon(MdiIcons.mail, size: 16, color: Colors.grey),
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 4),
                                                    child: Text(
                                                      "${data.unreadMessages} ungelesene Nachricht${data.unreadMessages == 1 ? "" : "en"}",
                                                      style: TextStyle(fontWeight: (data.unreadMessages > 0) ? FontWeight.bold : null),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text("Für Aktionen lange auf E-Mail gedrückt halten.", textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.w500)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          }

                          /// sonst einfach Mails anzeigen
                          final mail = mails[i - 1];
                          return Padding(
                            padding: const EdgeInsets.all(4),
                            child: LSMailTile(
                              mail: mail,
                              folderId: widget.selectedFolder.id,
                              iconColor: color,
                              onAfterSuccessfulMailAction: () {
                                widget.controller?.onForceRefresh?.call();
                              },
                              login: widget.login,
                              token: widget.token,
                              alternative: widget.alternative,
                            ),
                          );
                        },
                        separatorBuilder: (context, i) => const Divider(),
                      ),
                    ),
                  );
                }
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    loadMailsInSelectedFolder();
    widget.controller?.onForceRefresh = () => loadMailsInSelectedFolder();
  }

  Future<void> loadMailsInSelectedFolder() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    // TODO - future: use limit, offset (offset = 0 -> newest messages) and "total_messages" to only get new emails on load
    // this might require an additional request with limit = 0 and offset = 0 to get the new total_messages and then load the new ones
    var (online, data) = await lernsax.getMailListings(widget.login, widget.token, folderId: widget.selectedFolder.id, isDraftsFolder: widget.selectedFolder.isDrafts, isSentFolder: widget.selectedFolder.isSent);
    if (!widget.alternative) {
      final text = (online == false && lsdata.lastMailListingsUpdateDiff.inHours >= 24 && lsdata.mailListings != null) ? " Hinweis: Die Daten sind älter als 24 Stunden. Es könnten neue E-Mails verfügbar sein." : "";
      if (!online) {
        showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?$text", error: true, clear: true);
        if (lsdata.mailListings != null) data = lsdata.mailListings;
      } else if (data == null) {
        showSnackBar(textGen: (sie) => "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} E-Mails. Bitte ${sie ? "probieren Sie" : "probiere"} es später erneut.$text", error: true, clear: true);
      } else {
        lsdata.mailListings = data;
        lsdata.lastMailListingsUpdate = DateTime.now();
        // showSnackBar(text: "Erfolgreich aktualisiert.");
      }
    } else {
      if (!online) {
        showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
      } else if (data == null) {
        showSnackBar(textGen: (sie) => "Fehler beim Abfragen der E-Mails. Bitte ${sie ? "probieren Sie" : "probiere"} es später erneut.", error: true, clear: true);
      }
    }
    loadMailState();
    if (!mounted) return;
    setState(() {
      _loading = false;
      mailListings = data;
    });
  }

  Future<void> loadMailState() async {
    if (!mounted) return;
    setState(() {
      mailData = null;
    });
    final newMailData = await lernsax.getMailState(widget.login, widget.token);
    if (!mounted) return;
    setState(() {
      mailData = newMailData;
    });
  }
}

enum LSMailAction { delete, move, forward, respond }

/// zeigt LSMail in ListTile an
class LSMailTile extends StatelessWidget {
  const LSMailTile({
    super.key,
    required this.mail,
    required this.folderId,
    required this.onAfterSuccessfulMailAction,
    this.darkerIcons = false,
    this.iconColor,
    required this.login,
    required this.token,
    required this.alternative,
  });

  /// anzuzeigende Mail
  final LSMailListing mail;
  /// Mail ist aus diesem Ordner
  /// 
  /// warum? warum nicht einfach mail.folderId? keine Ahnung.
  /// TODO: aufklären, warum folderId separat übergeben wird
  final String folderId;
  /// sollen die Icons mit dunkleren Farben dargestellt werden?
  final bool darkerIcons;
  /// falls gegeben ist, wird `darkerIcons` ignoriert und nur dies als Icon-Farbe verwenden
  final Color? iconColor;
  /// wird aufgerufen, nachdem eine Aktion auf der Mail erfolgreich ausgeführt wurde
  final void Function()? onAfterSuccessfulMailAction;
  /// zu verwendender LS-Login
  final String login;
  /// zu verwendendes LS-Token
  final String token;
  /// wird nicht der primäre LS-Account verwendet?
  final bool alternative;

  @override
  Widget build(BuildContext context) {
    final lsdata = Provider.of<LernSaxData>(context);
    final lernSaxLogin = Provider.of<CredentialStore>(context, listen: false).lernSaxLogin;
    return GestureDetector(
      onLongPressStart: (details) {
        final overlay = Overlay.of(context).context.findRenderObject();
        showMenu(
          context: context,
          position: RelativeRect.fromRect(
            details.globalPosition & const Size(40, 40), // smaller rect, the touch area
            Offset.zero & overlay!.semanticBounds.size, // Bigger rect, the entire screen
          ),
          items: [
            // you dont really need this, i dont know anyone who uses folders for mails on lernsax
            // const PopupMenuItem(
            //   value: LSMailAction.move,
            //   child: ListTile(
            //     leading: Icon(Icons.folder_copy),
            //     title: Text("Verschieben"),
            //   ),
            // ),
            const PopupMenuItem(
              value: LSMailAction.respond,
              child: ListTile(
                leading: Icon(Icons.send_rounded),
                title: Text("Antworten"),
              ),
            ),
            const PopupMenuItem(
              value: LSMailAction.forward,
              child: ListTile(
                leading: Icon(Icons.forward_rounded),
                title: Text("Weiterleiten"),
              ),
            ),
            const PopupMenuItem(
              value: LSMailAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text("Löschen"),
              ),
            ),
          ],
          popUpAnimationStyle: AnimationStyle(
            duration: const Duration(milliseconds: 200),
          ),
        ).then((action) async {
          if (action == null) return;
          switch (action) {
            case LSMailAction.delete:
              // ignore: use_build_context_synchronously
              final trashFolder = (alternative ? (await lernsax.getMailFolders(login, token)).$2 : Provider.of<LernSaxData>(context, listen: false).mailFolders)?.cast<LSMailFolder?>().firstWhere((f) => f!.isTrash == true, orElse: () => null);
              if (trashFolder == null) {
                showSnackBar(text: "Fehler beim Abfragen der Ordnerliste von LernSax.");
                return;
              }
              if (!context.mounted) return;
              final alrInTrash = mail.folderId == trashFolder.id;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(alrInTrash ? "Endgültig löschen?" : "In Papierkorb verschieben?"),
                  content: Text("E-Mail \"${mail.subject}\" von ${mail.addressed.map((m) => m.address).join(", ")} wirklich ${alrInTrash ? "endgültig löschen? Dies kann nicht rückgängig gemacht werden!" : "in den Papierkorb verschieben? Dort wird sie nach einiger Zeit automatisch gelöscht."}"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Abbrechen")),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Ja, ${alrInTrash ? "löschen" : "verschieben"}")),
                  ],
                ),
              ).then((selected) {
                if (selected == true) {
                  (
                    alrInTrash ?
                    lernsax.deleteMail(login, token, folderId: mail.folderId, mailId: mail.id)
                    :
                    lernsax.moveMailToFolder(login, token, folderId: mail.folderId, mailId: mail.id, targetFolderId: trashFolder.id)
                  ).then((data) {
                    final (online, success) = data;
                    if (!online) {
                      showSnackBar(text: "Fehler bei der Verbindung mit LernSax.");
                    } else if (!success) {
                      showSnackBar(text: "Fehler beim ${alrInTrash ? "Auslöschen der E-Mail" : "Verschieben der E-Mail in den Müll"}.");
                    } else {
                      showSnackBar(text: "E-Mail erfolgreich ${alrInTrash ? "endgültig gelöscht" : "in den Papierkorb verschoben"}.");
                      onAfterSuccessfulMailAction?.call();
                    }
                  });
                }
              });
              break;
            case LSMailAction.forward:
            case LSMailAction.respond:
              late LSMail mailData;
              if (!context.mounted) return;
              final lsdata = Provider.of<LernSaxData>(context, listen: false);

              final mailDataCached = lsdata.getCachedMail(mail.folderId, mail.id);
              if (mailDataCached != null && !mail.isDraft && !alternative) {
                mailData = mailDataCached;
              } else {
                final (online, mailDataLive) = await lernsax.getMail(login, token, folderId: mail.folderId, mailId: mail.id);
                if (!online) {
                  showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
                  return;
                } else if (mailDataLive == null) {
                  showSnackBar(textGen: (sie) => "Fehler beim Abfragen der E-Mail. Bitte ${sie ? "probieren Sie" : "probiere"} es später erneut.", error: true, clear: true);
                  return;
                } else {
                  if (!mail.isDraft && !alternative) lsdata.addMailToCache(mailDataLive);
                  mailData = mailDataLive;
                }
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => MailWritePage(
                    subject: "${action == LSMailAction.forward ? "Fwd" : "Re"}: ${mail.subject}",
                    mail: (action == LSMailAction.forward) ?
                      "gesendet von ${mail.addressed.map((e) => e.address).join(", ")}:\n\n${mailData.bodyPlain}" :
                      /// wird von den offiziellen LernSax-Clients so eingeschoben, wird nicht übersetzt
                      "\n\n> -----Original Message-----\n> From: ${mailData.from.map((m) => "\"${m.name}\" <${m.address}>").join(", ")}\n> Sent: ${DateFormat("dd.MM.yyyy HH:mm").format(mailData.date)}\n> To: ${mailData.to.map((m) => m.address).join(", ")}\n> Subject: ${mailData.subject}\n> \n> ${joinWithOptions(mailData.bodyPlain.split("\n"), "\n> ", "")}",
                    reference: mailData,
                    referenceMode: action == LSMailAction.forward ? LSMWPReferenceMode.forwarded : LSMWPReferenceMode.answered,
                    to: action == LSMailAction.respond ? mailData.from.map((m) => m.address).toList() : null,
                    /// dies funktioniert sehr gut, da indexWhere -1 zurückgibt, wenn es nichts findet
                    /// bei preselectedAccount bedeutet 0 dann primärer Account, sonst ist das index - 1 -> geht also
                    /// perfekt hier auf
                    preselectedAccount: Provider.of<CredentialStore>(ctx, listen: false).alternativeLSLogins.indexWhere((l) => l == login) + 1,
                  ),
                ),
              );
            default:
          }
        });
      },
      child: TextButton(
        style: TextButton.styleFrom(
          textStyle: Theme.of(context).textTheme.bodyMedium,
          foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => Provider.of<AppState>(context, listen: false).infoScreen = InfoScreenDisplay(infoScreens: [InfoScreen(customScreen: MailDetailPage(listing: mail, login: login, token: token, alternative: alternative))]),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(MdiIcons.clock, size: 16, color: iconColor ?? (darkerIcons ? Colors.grey.shade900 : Colors.grey)),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(lernSaxTimeFormat.format(mail.date)),
                  ),
                  const Spacer(),
                  Icon(MdiIcons.file, size: 16, color: iconColor ?? (darkerIcons ? Colors.grey.shade900 : Colors.grey)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text("${(mail.size / 1024 * 100).round() / 100} KB"),
                  ),
                  if (lsdata.mailCache.where((m) => m.id == mail.id && m.folderId == mail.folderId).isNotEmpty && !alternative)
                    Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message: "E-Mail ist offline verfügbar",
                      child: CircleAvatar(
                        backgroundColor: iconColor ?? (hasDarkTheme(context) ? Colors.grey.shade700 : (darkerIcons ? Colors.grey.shade900 : Colors.grey)),
                        radius: 8,
                        child: const Icon(Icons.file_download_done, color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                SizedBox(width: 28, child: Icon(Icons.mail, color: iconColor ?? (darkerIcons ? Colors.grey.shade900 : Colors.grey))),
                Flexible(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    mail.subject,
                    style: (mail.isUnread && !mail.isDraft) ? const TextStyle(fontWeight: FontWeight.bold) : null,
                  ),
                )),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Icon(MdiIcons.account, color: iconColor ?? (darkerIcons ? Colors.grey.shade900 : Colors.grey))),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: "${mail.isDraft || mail.isSent ? "an" : "von"} "),
                            ...mail.addressed.map((addr) {
                              final sie = Provider.of<Preferences>(context, listen: false).preferredPronoun == Pronoun.sie;
                              return createLSMailAddressableSpan(
                                (addr.address == lernSaxLogin) ? LSMailAddressable(address: addr.address, name: mail.isDraft || mail.isSent ? (sie ? "Sie" : "Dich") : (sie ? "Ihnen" : "Dir")) : addr,
                                mail.addressed.last == addr,
                                /// ist etwas hacky, aber sonst ist der Text im Vergleich zu dem anderen verschoben
                                translate: const Offset(0, 2),
                                darkerIcon: darkerIcons,
                              );
                            }),
                            if (mail.addressed.isEmpty) const TextSpan(text: "niemanden", style: TextStyle(fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            /// da im MailListing keinerlei Infos über die Anhänge gespeichert ist, muss für die Anzeige von Anhängen
            /// die komplette Mail heruntergeladen werden
            /// -> darum kümmert sich dieses Widget - es lädt, sobald es angezeigt wird, die Mail herunter,
            /// cached sie (falls primär) und zeigt die Anhänge an (kann per Einstellung gesteuert werden)
            AttachmentAmountDisplay(
              folderId: folderId,
              mailId: mail.id,
              isDraft: mail.isDraft,
              iconColor: iconColor,
              login: login,
              token: token,
              alternative: alternative,
            ),
          ],
        ),
      ),
    );
  }
}

/// Infos über die Anhänge von Mails sind nur in den Daten mit der Mail selbst gespeichert, und da für das
/// Cache-Abfragen State notwendig ist (wait - vielleicht nicht? hätte ein FutureBuilder gereicht?)
/// ist dies ein seperates Widget, was bei Anzeige die Daten herunterladen und cached (für primären Account)
class AttachmentAmountDisplay extends StatefulWidget {
  /// LS-Mail-Ordner-ID
  final String folderId;
  /// ID der Mail
  final int mailId;
  /// ist die Mail ein Entwurf?
  final bool isDraft;
  /// Farbe des Icons
  final Color? iconColor;
  /// zu verwendender LS-Login
  final String login;
  /// zu verwendendes LS-Token
  final String token;
  /// wird nicht der primäre LS-Account verwendet?
  final bool alternative;

  const AttachmentAmountDisplay({super.key, required this.folderId, required this.mailId, required this.isDraft, this.iconColor, required this.login, required this.token, required this.alternative});

  @override
  State<AttachmentAmountDisplay> createState() => _AttachmentAmountDisplayState();
}

class _AttachmentAmountDisplayState extends State<AttachmentAmountDisplay> {
  int? attachmentAmount;
  List<String> attachmentNames = [];

  @override
  Widget build(BuildContext context) {
    if ((attachmentAmount ?? 0) == 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Transform.rotate(
              angle: 15,
              child: Icon(Icons.attach_file, size: 20, color: widget.iconColor),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                "$attachmentAmount ${attachmentAmount == 1 ? "Anhang" : "Anhänge"}: ${attachmentNames.join(", ")}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAttachmentInfo();
  }

  Future<void> _loadAttachmentInfo() async {
    final lsdata = Provider.of<LernSaxData>(context, listen: false);

    final cachedMail = lsdata.getCachedMail(widget.folderId, widget.mailId);
    if (cachedMail != null && !widget.alternative && !widget.isDraft) {
      if (!mounted) return;
      setState(() {
        attachmentAmount = cachedMail.attachments.length;
        attachmentNames = cachedMail.attachments.map((att) => att.name).toList();
      });
    // only load data from the Neuland if the user enabled it
    } else if (Provider.of<Preferences>(context, listen: false).lernSaxAutoLoadMailOnScrollBy) {
      final (online, mail) = await lernsax.getMail(widget.login, widget.token, folderId: widget.folderId, mailId: widget.mailId, peek: true);
      if (!online || mail == null) return;
      if (!widget.isDraft && !widget.alternative) lsdata.addMailToCache(mail);
      if (!mounted) return;
      setState(() {
        attachmentAmount = mail.attachments.length;
        attachmentNames = mail.attachments.map((att) => att.name).toList();
      });
    }
  }
}
