import 'dart:io';

import 'package:appcheck/appcheck.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/lernsax/lernsax.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/lernsax/pages/mail_detail_page.dart';
import 'package:kepler_app/tabs/lernsax/pages/notifs_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

final lsMailPageKey = GlobalKey<_LSMailsPageState>();

void lernSaxMailsRefreshAction() {
  lsMailPageKey.currentState
    ?..loadData(force: true)
    ..dayDispController.onForceRefresh?.call();
}

class LSMailsPage extends StatefulWidget {
  LSMailsPage() : super(key: lsMailPageKey);

  @override
  State<LSMailsPage> createState() => _LSMailsPageState();
}

class _LSMailsPageState extends State<LSMailsPage> {
  bool _loadingFolders = false;
  String? selectedFolderId;
  final LSMailDispController dayDispController = LSMailDispController();

  String improveName(String oldName) {
    if (oldName == "INBOX") return "Posteingang";
    if (oldName == "SPAM") return "Spam";
    return oldName;
  }
  
  @override
  Widget build(BuildContext context) {
    if (_loadingFolders) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Consumer<LernSaxData>(
      builder: (context, lsdata, child) {
        if (lsdata.mailFolders == null) {
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
        return Column(
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
                    value: selectedFolderId,
                  ),
                ),
              ),
            ),
            Flexible(
              child: (selectedFolderId != null)
                ? LSMailDisplay(
                    key: ValueKey(selectedFolderId),
                    selectedFolder: lsdata.mailFolders!.firstWhere((f) => f.id == selectedFolderId),
                    controller: dayDispController,
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
      }
    );
  }

  @override
  void initState() {
    loadData().then((folderIds) {
      final prev = Provider.of<InternalState>(context, listen: false).lastSelectedLSMailFolder;
      if (prev != null && folderIds != null && folderIds.contains(prev)) {
        setState(() => selectedFolderId = prev);
      } else if (folderIds != null) {
        setState(() => selectedFolderId = folderIds.first);
      } else {
        setState(() => selectedFolderId = null);
      }
    });
    super.initState();
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

class LSMailDisplay extends StatefulWidget {
  final LSMailFolder selectedFolder;
  final LSMailDispController? controller;

  const LSMailDisplay({super.key, required this.selectedFolder, this.controller});

  @override
  State<LSMailDisplay> createState() => _LSMailDisplayState();
}

class _LSMailDisplayState extends State<LSMailDisplay> {
  bool _loading = true;
  (bool, LSMailState?)? mailData;
  
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
        final mails = lsdata.mailListings?.where((e) => e.folderId == widget.selectedFolder.id).toList();
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
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              showDialog(context: context, builder: (context) => AlertDialog(
                title: const Text("E-Mail schreiben"),
                content: const Text("E-Mails können aktuell nur in LernSax Messenger verfasst werden."), // TODO - future: add a basic email writer with just a mail, subject and text input
                actions: [
                  FutureBuilder(
                    future: AppCheck.checkAvailability(lernSaxMsgrAndroidPkg).catchError((_) => null),
                    builder: (context, datasn) {
                      return TextButton(
                        onPressed: () {
                          if (Platform.isAndroid) {
                            AppCheck.launchApp(lernSaxMsgrAndroidPkg).catchError((_) => launchUrl(Uri.parse("market://details?id=$lernSaxMsgrAndroidPkg")).catchError((_) {
                              showSnackBar(text: "Keine App zum Installieren von Apps gefunden.", error: true);
                              return false;
                            }));
                          } else if (Platform.isIOS) {
                            launchUrl(Uri.parse("https://apps.apple.com/de/app/id$lernSaxMsgrAppleAppId"), mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Text("Jetzt ${Platform.isIOS ? "öffnen/installieren" : datasn.data != null ? "öffnen" : "installieren"}"),
                      );
                    },
                  ),
                ],
              ));
            },
            child: const Icon(Icons.edit_note),
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
              if (mails.isNotEmpty) Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: mails.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Builder(
                          builder: (context) {
                            final online = mailData?.$1 ?? false, data = mailData?.$2;
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                              child: (mailData == null) ?
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
                                        const Icon(MdiIcons.fileCabinet, size: 16, color: Colors.grey),
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
                                        const Icon(MdiIcons.mail, size: 16, color: Colors.grey),
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
                            );
                          },
                        ),
                      );
                    }
                    final mail = mails[i - 1];
                    // TODO - future: long press actions -> delete mail, move to other folder, ...
                    return Padding(
                      padding: const EdgeInsets.all(4),
                      child: LSMailTile(mail: mail, folderId: widget.selectedFolder.id),
                    );
                  },
                  separatorBuilder: (context, i) => const Divider(),
                ),
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
    setState(() => _loading = true);
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    // TODO - future: use limit, offset (offset = 0 -> newest messages) and "total_messages" to only get new emails on load
    // this might require an additional request with limit = 0 and offset = 0 to get the new total_messages and then load the new ones
    final (online, data) = await lernsax.getMailListings(creds.lernSaxLogin!, creds.lernSaxToken!, folderId: widget.selectedFolder.id, isDraftsFolder: widget.selectedFolder.isDrafts, isSentFolder: widget.selectedFolder.isSent);
    final text = (online == false && lsdata.lastMailListingsUpdateDiff.inHours >= 24 && lsdata.mailListings != null) ? " Hinweis: Die Daten sind älter als 24 Stunden. Es könnten neue E-Mails verfügbar sein." : "";
    if (!online) {
      showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?$text", error: true, clear: true);
    } else if (data == null) {
      showSnackBar(textGen: (sie) => "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} E-Mails. Bitte ${sie ? "probieren Sie" : "probiere"} es später erneut.$text", error: true, clear: true);
    } else {
      lsdata.mailListings = data;
      lsdata.lastMailListingsUpdate = DateTime.now();
      // showSnackBar(text: "Erfolgreich aktualisiert.");
    }
    loadMailState();
    setState(() {
      _loading = false;
    });
  }

  Future<void> loadMailState() async {
    if (!mounted) return;
    final creds = Provider.of<CredentialStore>(context, listen: false);
    setState(() {
      mailData = null;
    });
    final newMailData = await lernsax.getMailState(creds.lernSaxLogin!, creds.lernSaxToken!);
    if (!mounted) return;
    setState(() {
      mailData = newMailData;
    });
  }
}

class LSMailTile extends StatelessWidget {
  const LSMailTile({
    super.key,
    required this.mail,
    required this.folderId,
  });

  final LSMailListing mail;
  final String folderId;

  @override
  Widget build(BuildContext context) {
    final lsdata = Provider.of<LernSaxData>(context);
    final lernSaxLogin = Provider.of<CredentialStore>(context, listen: false).lernSaxLogin;
    return TextButton(
      style: TextButton.styleFrom(
        textStyle: Theme.of(context).textTheme.bodyMedium,
        foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => Provider.of<AppState>(context, listen: false).infoScreen = InfoScreenDisplay(infoScreens: [InfoScreen(customScreen: MailDetailPage(listing: mail))]),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(MdiIcons.clock, size: 16, color: Colors.grey),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(lernSaxTimeFormat.format(mail.date)),
                ),
                const Spacer(),
                const Icon(MdiIcons.file, size: 16, color: Colors.grey),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text("${(mail.size / 1024 * 100).round() / 100} KB"),
                ),
                if (lsdata.mailCache.where((m) => m.id == mail.id && m.folderId == mail.folderId).isNotEmpty)
                  Tooltip(
                    triggerMode: TooltipTriggerMode.tap,
                    message: "E-Mail ist offline verfügbar",
                    child: CircleAvatar(
                      backgroundColor: hasDarkTheme(context) ? Colors.grey.shade700 : Colors.grey,
                      radius: 8,
                      child: const Icon(Icons.file_download_done, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 28, child: Icon(Icons.mail)),
              Flexible(
                  child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  mail.subject,
                  style: (mail.isUnread) ? const TextStyle(fontWeight: FontWeight.bold) : null,
                ),
              )),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const SizedBox(width: 28, child: Icon(MdiIcons.account)),
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
                              translate: const Offset(0, 2),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AttachmentAmountDisplay(folderId: folderId, mailId: mail.id, isDraft: mail.isDraft),
        ],
      ),
    );
  }
}

class AttachmentAmountDisplay extends StatefulWidget {
  final String folderId;
  final int mailId;
  final bool isDraft;

  const AttachmentAmountDisplay({super.key, required this.folderId, required this.mailId, required this.isDraft});

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
              child: const Icon(Icons.attach_file, size: 20),
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
    final creds = Provider.of<CredentialStore>(context, listen: false);

    final cachedMail = lsdata.getCachedMail(widget.folderId, widget.mailId);
    if (cachedMail != null) {
      if (!mounted) return;
      setState(() {
        attachmentAmount = cachedMail.attachments.length;
        attachmentNames = cachedMail.attachments.map((att) => att.name).toList();
      });
    // only load data from the Neuland if the user enabled it
    } else if (Provider.of<Preferences>(context, listen: false).lernSaxAutoLoadMailOnScrollBy) {
      final (online, mail) = await lernsax.getMail(creds.lernSaxLogin!, creds.lernSaxToken!, folderId: widget.folderId, mailId: widget.mailId, peek: true);
      if (!online || mail == null) return;
      if (!widget.isDraft) lsdata.addMailToCache(mail);
      if (!mounted) return;
      setState(() {
        attachmentAmount = mail.attachments.length;
        attachmentNames = mail.attachments.map((att) => att.name).toList();
      });
    }
  }
}
