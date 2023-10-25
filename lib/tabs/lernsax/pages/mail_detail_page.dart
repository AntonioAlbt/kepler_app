import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// this class is supposed to be shown as a customWidget on an InfoScreen -> InfoScreenDisplay
/// this is neccessary for it to still have access to the context that can access all the Provider-s
class MailDetailPage extends StatefulWidget {
  final LSMailListing listing;

  const MailDetailPage({super.key, required this.listing});

  @override
  State<MailDetailPage> createState() => _MailDetailPageState();
}

// TODO: improve design?
// TODO: show attachments and open a download link in the browser on click
class _MailDetailPageState extends State<MailDetailPage> {
  bool _loading = true;
  LSMail? mailData;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (mailData == null) return const Center(child: Text("Fehler."));
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
                          child: SelectableText.rich(
                            TextSpan(
                              children: [
                                ...mailData!.from.map((addr) => createLSMailAddressableSpan(addr, mailData!.from.last == addr)),
                                if (mailData!.from.isEmpty) const TextSpan(text: "niemandem!?"),
                              ]
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
                          child: SelectableText.rich(
                            TextSpan(
                              children: [
                                ...mailData!.to.map((addr) => createLSMailAddressableSpan(addr, mailData!.to.last == addr))
                              ]
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SelectableText(mailData!.subject, style: Theme.of(context).textTheme.bodyLarge!.copyWith(decoration: TextDecoration.underline)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SelectableLinkify(
                      // change order so emails get linkified first, is needed because of looseUrl
                      linkifiers: const [EmailLinkifier(), UrlLinkifier()],
                      options: const LinkifyOptions(looseUrl: true, defaultToHttps: true),
                      onOpen: (link) {
                        if (link.text.contains("@")) {
                          showDialog(context: context, builder: (context) => AlertDialog(
                            content: Text("E-Mail-Adresse: ${link.text}", style: const TextStyle(fontSize: 18)),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  launchUrl(Uri.parse(link.url), mode: LaunchMode.externalNonBrowserApplication).catchError((_) {
                                    showSnackBar(text: "Keine App für E-Mails gefunden.");
                                    return false;
                                  });
                                  Navigator.pop(context);
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
                          return;
                        }
                        try {
                          launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication);
                        } on Exception catch (_) {
                          showSnackBar(text: "Keine App zum Öffnen dieses Links gefunden.");
                        }
                      },
                      text: mailData!.bodyPlain,
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

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final lsdata = Provider.of<LernSaxData>(context, listen: false);

    final mailDataCached = lsdata.mailCache.cast<LSMail?>().firstWhere((ml) => ml!.id == widget.listing.id && ml.folderId == widget.listing.folderId, orElse: () => null);
    if (mailDataCached != null) {
      mailData = mailDataCached;
    } else {
      final (online, mailDataLive) = await lernsax.getMail(creds.lernSaxLogin!, creds.lernSaxToken!, folderId: widget.listing.folderId, mailId: widget.listing.id);
      if (!online) {
        showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
        Provider.of<AppState>(globalScaffoldContext, listen: false).clearInfoScreen();
        return;
      } else if (mailDataLive == null) {
        showSnackBar(textGen: (sie) => "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} E-Mails. Bitte ${sie ? "probieren Sie" : "probiere"} es später erneut.", error: true, clear: true);
        Provider.of<AppState>(globalScaffoldContext, listen: false).clearInfoScreen();
        return;
      } else {
        if (!widget.listing.isDraft) lsdata.addMailToCache(mailDataLive);
        mailData = mailDataLive;
      }
    }
    setState(() => _loading = false);
  }
}

InlineSpan createLSMailAddressableSpan(LSMailAddressable addressable, bool isLast)
  => createLSNameMailSpan(addressable.name, addressable.address, addComma: !isLast);

InlineSpan createLSNameMailSpan(String? name, String? mail, { bool addComma = true})
  => WidgetSpan(
    child: Tooltip(
      preferBelow: false,
      verticalOffset: 8,
      triggerMode: (mail != name) ? TooltipTriggerMode.tap : TooltipTriggerMode.manual,
      message: mail,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: name ?? mail ?? "unbekannt"),
            if (name != mail) const WidgetSpan(child: Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.info, size: 16, color: Colors.grey),
            )),
            if (addComma) const TextSpan(text: ", "),
          ],
        ),
      ),
    ),
  );
