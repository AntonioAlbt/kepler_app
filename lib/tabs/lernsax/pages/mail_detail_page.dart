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
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/lernsax/pages/mail_write_page.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// this class is supposed to be shown as a customWidget on an InfoScreen -> InfoScreenDisplay
/// this is neccessary for it to still have access to the context that can access all the Provider-s
/// - ich hätte auch damals schon `globalScaffoldContext` verwenden können, aber das ist halt schlechter Stil
class MailDetailPage extends StatefulWidget {
  /// Mail, die angezeigt werden soll (LSMail wird selbst geladen)
  final LSMailListing listing;
  /// zu verwendender Login
  final String login;
  /// zu verwendendes Token
  final String token;
  /// wird nicht der primäre LS-Account verwendet?
  final bool alternative;

  const MailDetailPage({super.key, required this.listing, required this.login, required this.token, required this.alternative});

  @override
  State<MailDetailPage> createState() => _MailDetailPageState();
}

class _MailDetailPageState extends State<MailDetailPage> {
  bool _loading = true;
  LSMail? mailData;
  bool isDraftMail = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (mailData == null) return const Center(child: Text("Fehler."));
    final attachmentCount = mailData!.attachments.length;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Text("E-Mail-Ansicht", style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (!widget.listing.isDraft && !widget.listing.isSent) Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                    child: Row(
                      children: [
                        const Expanded(flex: 1, child: Text("Absender:")),
                        Expanded(
                          flex: 3,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                ...mailData!.from.map((addr) => createLSMailAddressableSpan(addr, mailData!.from.last == addr)),
                                if (mailData!.from.isEmpty) const TextSpan(text: "niemandem!?"),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: (widget.listing.isDraft) ? const EdgeInsets.fromLTRB(0, 8, 0, 4) : const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Text("${(widget.listing.isDraft) ? "Geplante${mailData!.to.length == 1 ? "r" : ""} " : ""}Empfänger: ")),
                        Expanded(
                          flex: 3,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                ...mailData!.to.map((addr) => createLSMailAddressableSpan(addr, mailData!.to.last == addr))
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (attachmentCount > 0) const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(),
                  ),
                  if (attachmentCount > 0) Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.attachment, size: 20, color: Colors.grey),
                        ),
                        Text(
                          "$attachmentCount ${attachmentCount == 1 ? "Anhang" : "Anhänge"}",
                          style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  if (attachmentCount > 0) Wrap(
                    children: mailData!.attachments.map((att) => TextButton(
                      style: TextButton.styleFrom(visualDensity: const VisualDensity(vertical: -2)),
                      onPressed: () {
                        // show this as a kind of loading message
                        showSnackBar(text: "\"${att.name}\" wird abgefragt...", clear: true, duration: const Duration(seconds: 10));
                        /// um einen Anhang herunterzuladen, muss er erst in eine Session-Datei exportiert werden,
                        /// dabei bekommt man dann einen Download-Link zurückgegeben und über diesen lässt er sich
                        /// dann herunterladen
                        lernsax.exportSessionFileFromMail(
                          widget.login,
                          widget.token,
                          folderId: mailData!.folderId,
                          mailId: mailData!.id,
                          attachmentId: att.id,
                        ).then((data) {
                          final (online, sessionFile) = data;
                          if (!online) {
                            showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", clear: true);
                          } else if (sessionFile == null) {
                            showSnackBar(text: "Fehler beim Abfragen der Datei. Bitte später erneut versuchen.", clear: true);
                          } else {
                            showSnackBar(text: "Download-Link wird geöffnet.", clear: true, duration: const Duration(seconds: 1));
                            launchUrl(Uri.parse(sessionFile.downloadUrl), mode: LaunchMode.externalApplication);
                          }
                        });
                      },
                      child: Text(att.name),
                    )).toList(),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Divider(),
                  ),
                  if (isDraftMail) ElevatedButton.icon(
                    onPressed: () {
                      Provider.of<AppState>(context, listen: false).clearInfoScreen();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => MailWritePage(
                            to: mailData!.to.map((to) => to.address).toList(),
                            subject: mailData!.subject,
                            mail: mailData!.bodyPlain,
                            /// beim Absenden soll der Entwurf, gespeichert in `mailData`, gelöscht werden
                            /// -> `draftToDelete` mit Referenz
                            reference: mailData!,
                            referenceMode: LSMWPReferenceMode.draftToDelete,                            
                            preselectedAccount: Provider.of<CredentialStore>(context, listen: false).alternativeLSLogins.indexWhere((l) => l == widget.login) + 1,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text("Bearbeiten und senden"),
                  ),
                  if (!isDraftMail) Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (mailData == null) return;
                        Provider.of<AppState>(context, listen: false).clearInfoScreen();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => MailWritePage(
                              subject: "Re: ${mailData!.subject}",
                              mail: "\n\n> -----Original Message-----\n> From: ${mailData!.from.map((m) => "\"${m.name}\" <${m.address}>").join(", ")}\n> Sent: ${DateFormat("dd.MM.yyyy HH:mm").format(mailData!.date)}\n> To: ${mailData!.to.map((m) => m.address).join(", ")}\n> Subject: ${mailData!.subject}\n> \n> ${joinWithOptions(mailData!.bodyPlain.split("\n"), "\n> ", "")}",
                              /// Mail ist eine Antwort auf `mailData`
                              reference: mailData,
                              referenceMode: LSMWPReferenceMode.answered,
                              to: mailData!.from.map((m) => m.address).toList(),
                              preselectedAccount: Provider.of<CredentialStore>(context, listen: false).alternativeLSLogins.indexWhere((l) => l == widget.login) + 1,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text("Antworten"),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      mailData!.subject,
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: SelectableLinkify(
                        // needed to show the real context menu like on a normal selectabletext, it somehow doesn't show otherwise
                        contextMenuBuilder: const SelectableText("").contextMenuBuilder,
                        // change order so emails get linkified first, is needed because of looseUrl
                        linkifiers: const [EmailLinkifier(), UrlLinkifier()],
                        /// looseUrl heißt, dass auch Urls wie example.com linkified werden, nicht nur https://example.com
                        options: const LinkifyOptions(looseUrl: true, defaultToHttps: true),
                        onOpen: (link) {
                          if (link.text.contains("@")) {
                            showDialog(context: context, builder: (context) => AlertDialog(
                              content: Text("E-Mail-Adresse: ${link.text}", style: const TextStyle(fontSize: 18)),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    /// da der aktuelle context hier gepopped wird, ab hier lieber globalen Kontext verwenden
                                    Navigator.push(
                                      globalScaffoldContext,
                                      MaterialPageRoute(
                                        builder: (ctx) => MailWritePage(
                                          to: [link.text],
                                          preselectedAccount: Provider.of<CredentialStore>(globalScaffoldContext, listen: false).alternativeLSLogins.indexWhere((l) => l == widget.login) + 1,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text("E-Mail senden"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: link.text));
                                    Navigator.pop(context);
                                  },
                                  child: const Text("Kopieren"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Schließen"),
                                ),
                              ],
                            ));
                          } else {
                            try {
                              launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication);
                            } on Exception catch (_) {
                              showSnackBar(text: "Keine App zum Öffnen dieses Links gefunden.");
                            }
                          }
                        },
                        text: mailData!.bodyPlain,
                      ),
                    ),
                  ),
                ],
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
    _loadData();
  }

  /// nur wenn der primäre Benutzer verwendet wird, wird eine eventuell gecachete Mail angezeigt oder eine
  /// abgefragte Mail im Cache gespeichert
  Future<void> _loadData() async {
    setState(() => _loading = true);
    final lsdata = Provider.of<LernSaxData>(context, listen: false);

    final mailDataCached = lsdata.getCachedMail(widget.listing.folderId, widget.listing.id);
    if (mailDataCached != null && !widget.listing.isDraft && !widget.alternative) {
      mailData = mailDataCached;
    } else {
      final (online, mailDataLive) = await lernsax.getMail(widget.login, widget.token, folderId: widget.listing.folderId, mailId: widget.listing.id);
      if (!online) {
        showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
        Provider.of<AppState>(context, listen: false).clearInfoScreen();
        return;
      } else if (mailDataLive == null) {
        showSnackBar(textGen: (sie) => "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} E-Mails. Bitte ${sie ? "probieren Sie" : "probiere"} es später erneut.", error: true, clear: true);
        Provider.of<AppState>(context, listen: false).clearInfoScreen();
        return;
      } else {
        if (!widget.listing.isDraft && !widget.alternative) lsdata.addMailToCache(mailDataLive);
        mailData = mailDataLive;
      }
    }
    isDraftMail = widget.listing.isDraft;
    setState(() => _loading = false);
  }
}

/// erstellt WidgetText für RichText, um Name/Login mit Symbol für Mail-Anzeige in Text einzubetten
InlineSpan createLSMailAddressableSpan(LSMailAddressable addressable, bool isLast, { Offset? translate, bool darkerIcon = false })
  => createLSNameMailSpan(addressable.name, addressable.address, addComma: !isLast, translate: translate, darkerIcon: darkerIcon);

InlineSpan createLSNameMailSpan(String? name, String? mail, { bool addComma = true, Offset? translate, bool darkerIcon = false })
  => WidgetSpan(
    child: Transform.translate(
      offset: translate ?? const Offset(0, 0),
      child: Tooltip(
        preferBelow: false,
        verticalOffset: 8,
        triggerMode: (mail != name) ? TooltipTriggerMode.tap : TooltipTriggerMode.manual,
        message: mail,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: name ?? mail ?? "unbekannt"),
              if (name != mail) WidgetSpan(child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.info, size: 16, color: darkerIcon ? Colors.grey.shade900 : Colors.grey),
              )),
              if (addComma) const TextSpan(text: ", "),
            ],
          ),
        ),
      ),
    ),
  );
