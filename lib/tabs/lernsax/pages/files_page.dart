import 'dart:math' show log;

import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/lernsax/pages/notifs_page.dart';
import 'package:kepler_app/tabs/pendel.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

final lsFoldersPageKey = GlobalKey<LSFilesPageState>();

void lernSaxFilesRefreshAction() {
  lsFoldersPageKey.currentState?.refreshData();
}

/// Dateien-Ansicht
class LSFilesPage extends StatefulWidget {
  /// zu verwendender LS-Login
  final String login;
  /// zu verwendendes LS-Token
  final String token;
  /// wird nicht der primäre LS-Account verwendet?
  final bool alternative;

  LSFilesPage(this.login, this.token, this.alternative) : super(key: lsFoldersPageKey);

  @override
  State<LSFilesPage> createState() => LSFilesPageState();
}

class LSFilesPageState extends State<LSFilesPage> {
  List<LSFileListing> path = [];
  List<LSFileListing>? listings;
  bool _loading = false;
  String _folderId = "/";
  String? _login;
  bool _canModify = false;
  int _changeToUpdateState = 0;

  List<LSFileListing> get _sortedListings {
    if (path.isNotEmpty) listings!.sort((a, b) => a.type == b.type ? a.name.compareTo(b.name) : b.type.index.compareTo(a.type.index));
    return listings!;
  }

  void _downloadFile(LSFileListing l) {
    showSnackBar(text: "Fragt Downloadlink ab...", duration: const Duration(seconds: 30), clear: true);
    lernsax.getFileDownloadUrl(widget.login, widget.token, fileLogin: _login ?? widget.login, id: l.id).then((res) {
      final (online, uri) = res;
      if (!online) {
        showSnackBar(text: "Fehler beim Verbinden mit LernSax.", clear: true, error: true);
        return;
      }
      if (uri == null) {
        showSnackBar(text: "Fehler beim Abfragen des Downloads.", clear: true, error: true);
        return;
      }
      showSnackBar(text: "Öffnet Downloadlink...", clear: true, duration: const Duration(seconds: 1));
      launchUrl(uri, mode: LaunchMode.externalApplication);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
        if (path.isEmpty) return;

        path.removeLast();
        if (_folderId != "/") {
          final fids = _folderId.split("/");
          fids.removeLast();
          _folderId = fids.join("/");
        }
        refreshData();
      },
      child: Scaffold(
        body: Column(
          // crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (path.isNotEmpty) Padding(
              padding: const EdgeInsets.all(8.0),
              child: BreadCrumb(
                items: [null, ...path].asMap().entries.map(
                  (p) => BreadCrumbItem(
                    content: p.value == null ? Icon(Icons.person) : Text(p.value!.name),
                    onTap: () {
                      if (p.key == 0) {
                        _login = null;
                        _folderId = "/";
                        path = [];
                      } else if (p.key == 1) {
                        _login = p.value!.id;
                        _folderId = "/";
                        path = [p.value!];
                      } else {
                        _folderId = p.value!.id;
                        path = path.sublist(0, p.key);
                      }
                      setState(() {});
                      refreshData();
                    },
                  ),
                ).toList(),
                divider: Icon(Icons.chevron_right),
                overflow: WrapOverflow(),
              ),
            ),
            if (path.isNotEmpty) ...[
              if (path.last.description != "" && path.length > 1) Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  path.last.description,
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                  maxLines: 10,
                ),
              ),
              const Divider(),
              const Padding(padding: EdgeInsets.all(2)),
            ] else const Padding(padding: EdgeInsets.all(8)),
            if (_loading) Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("Lädt Dateien..."),
                    ),
                  ],
                ),
              ),
            ) else if (!_loading && listings != null) Expanded(
              child: ListView(
                children: [
                  ..._sortedListings.map(
                    (l) => LSFileListingDisplay(
                      listing: l,
                      onOpen: () {
                        switch (l.type) {
                          case LSFileType.file:
                            _downloadFile(l);
                            break;
                          case LSFileType.folder:
                            _folderId = l.id;
                            path.add(l);
                          case LSFileType.account:
                            path = [l];
                            _login = l.id;
                            _canModify = l.size > 0;
                          case LSFileType.unknown:
                            path.removeLast();
                            if (path.isEmpty) {
                              _folderId = "/";
                              _login = null;
                            } else {
                              /// falls zurück zu "/" gewechselt wird, wäre nur noch die Account-ID in path - deshalb hier
                              /// abfangen und stattdessen "/" setzen
                              _folderId = (path.length == 1) ? "/" : path.last.id;
                            }
                        }
                        refreshData();
                      },
                      onDownload: _downloadFile,
                    ),
                  ),
                  if (listings!.every((l) => l.type == LSFileType.unknown)) Center(child: Text("\nDieser Ordner ist leer.", style: Theme.of(context).textTheme.bodyLarge)),
                ],
              ),
            )
            else Expanded(
              child: Center(
                child: Selector<Preferences, bool>(
                  selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
                  builder: (ctx, sie, _) => Text.rich(TextSpan(
                    children: [
                      TextSpan(text: "Fehler beim Abfragen der Dateien.\n", style: TextStyle(fontSize: 16)),
                      TextSpan(text: "${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?"),
                    ],
                  ), textAlign: TextAlign.center),
                ),
              ),
            ),
            if (_login != null && path.length == 1) ...[
              const Divider(),
              Flexible(
                flex: 0,
                fit: FlexFit.tight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 8),
                  child: FutureBuilder(
                    key: Key("$_login -> $_folderId ($path) - $_changeToUpdateState"),
                    future: lernsax.getFileState(widget.login, widget.token, fileLogin: _login ?? widget.login),
                    builder: (ctx, snapshot) {
                      if (!snapshot.hasData && !snapshot.hasError) {
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text("Fragt Status ab..."),
                            ),
                          ],
                        );
                      }
                      if (snapshot.hasError) {
                        return Text("Fehler beim Abfragen vom Status.");
                      }
                      if (snapshot.hasData) {
                        final (online, data) = snapshot.data!;
                        if (!online || data == null) {
                          return Text("Problem beim Abfragen vom Status.");
                        } else {
                          return Column(children: [
                            Text("Belegter Speicherplatz: ${_formatSize(data.usage)}"),
                            Text("Freier Speicherplatz: ${_formatSize(data.free)}"),
                            Text("Speicherplatz: ${_formatSize(data.limit)}"),
                          ]);
                        }
                      }
                      return SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
        floatingActionButton: (_canModify && _login != null) ? FloatingActionButton(
          child: Icon(Icons.upload),
          onPressed: () {},
        ) : null,
      ),
    );
  }

  Future<void> refreshData() async {
    setState(() => _loading = true);
    _changeToUpdateState++;
    final placeholderMeta = LSFileMeta(date: 0, userLogin: "", userName: "");
    if (path.isEmpty) {
      final (online, data) = await lernsax.getGroupsAndClasses(widget.login, widget.token);
      if (!online || data == null) {
        listings = null;
      } else {
        listings = [
          LSFileListing(
            type: LSFileType.account,
            id: widget.login,
            parentId: "",
            name: "Persönliche Dateien",
            description: "von ${widget.login}",
            size: 1,
            created: placeholderMeta,
            modified: placeholderMeta,
          ),
          ...(data.where((m) => m.effectiveRights.contains("files") || m.effectiveRights.contains("files_write")).toList()..sort((a, b) => a.type.compareTo(b.type))).map((m) => LSFileListing(
            type: LSFileType.account,
            id: m.login,
            parentId: "",
            name: m.name,
            description: "Dateien (${m.type.toString()})",
            size: (m.effectiveRights.contains("files_write") || m.effectiveRights.contains("files_admin")) ? 1 : 0,
            created: placeholderMeta,
            modified: placeholderMeta,
          )),
        ];
      }
    } else {
      final (online, data) = await lernsax.listFiles(widget.login, widget.token, fileLogin: _login ?? widget.login, folderId: _folderId);
      if (!online) {
        listings = null;
      } else {
        listings = [
          LSFileListing(type: LSFileType.unknown, id: "back", parentId: "", name: "Zurück", description: "zu${path.length >= 2 ? (" ${path[path.length - 2].name}") : "r Übersicht"}", size: -1, created: placeholderMeta, modified: placeholderMeta),
          ...?data,
        ];
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void initState() {
    refreshData();
    super.initState();
  }
}

String _formatSize(int bytes) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB"];
  int i = (bytes == 0) ? 0 : (log(bytes) / log(1024)).floor();
  double size = bytes / (1 << (10 * i));
  return "${formatForDisplay(size, 2)} ${suffixes[i]}";
}

final _fileDateFormat = DateFormat("dd.MM.yy HH:mm");

class LSFileListingDisplay extends StatelessWidget {
  final LSFileListing listing;
  final void Function()? onOpen;
  final void Function(LSFileListing)? onDownload;

  const LSFileListingDisplay({super.key, required this.listing, this.onOpen, this.onDownload});

  IconData _getIcon() => switch (listing.type) {
    LSFileType.file => Icons.description,
    LSFileType.folder => Icons.folder,
    LSFileType.account => Icons.person,
    LSFileType.unknown => Icons.arrow_upward,
  };

  @override
  Widget build(BuildContext context) {
    final uploadDate = DateTime.fromMillisecondsSinceEpoch(listing.created.date * 1000);
    return ListTile(
      onTap: onOpen,
      leading: Icon(_getIcon()),
      title: Text(listing.name),
      subtitle: (listing.type != LSFileType.account && listing.type != LSFileType.unknown) ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // if (listing.description != "") Text(listing.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.start,
              children: [
                if (listing.type == LSFileType.file) Transform.translate(offset: const Offset(0, 2), child: Icon(MdiIcons.fileCabinet, size: 16)),
                if (listing.type == LSFileType.file) Padding(
                  padding: const EdgeInsets.only(left: 2, right: 4),
                  child: Text(_formatSize(listing.size)),
                ),
                Transform.translate(offset: const Offset(0, 2), child: Icon(Icons.upload, size: 16)),
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: 4),
                  child: Text(_fileDateFormat.format(uploadDate)),
                ),
              ],
            ),
          ),
        ],
      ) : Text(listing.description),
      visualDensity: const VisualDensity(vertical: -4, horizontal: -1),
      trailing: (listing.type == LSFileType.file || listing.type == LSFileType.folder) ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: () {
            showDialog(context: context, builder: (ctx) => generateLSFileInfoDialog(ctx, listing, onDownload));
          }, icon: Icon(Icons.info)),
        ],
      ) : null,
    );
  }
}

Widget generateLSFileInfoDialog(BuildContext context, LSFileListing listing, void Function(LSFileListing)? onDownload) {
  return AlertDialog(
    content: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoDialogEntry(icon: Icons.label, text: listing.name),
            if (listing.description != "") InfoDialogEntry(icon: Icons.text_fields, text: listing.description),
            InfoDialogEntry(icon: MdiIcons.fileCabinet, text: "Typ: ${listing.type}"),
            InfoDialogEntry(icon: MdiIcons.archive, text: "Größe: ${_formatSize(listing.size)}${listing.size > 1024 ? " (${listing.size} B)" : ""}"),
            InfoDialogEntry(icon: MdiIcons.fileUpload, text: "Hochgeladen: ${_fileDateFormat.format(DateTime.fromMillisecondsSinceEpoch(listing.created.date * 1000))}\nvon: ${listing.created.userName ?? listing.created.userLogin}${listing.created.userName != null ? " (${listing.created.userLogin})" : ""}"),
            InfoDialogEntry(icon: MdiIcons.fileEdit, text: "Bearbeitet: ${_fileDateFormat.format(DateTime.fromMillisecondsSinceEpoch(listing.created.date * 1000))}\nvon: ${listing.created.userName ?? listing.created.userLogin}${listing.created.userName != null ? " (${listing.created.userLogin})" : ""}"),
          ],
        ),
      ),
    ),
    actions: [
      if (onDownload != null && listing.type == LSFileType.file) TextButton(onPressed: () {
        onDownload(listing);
        Navigator.pop(context);
      }, child: Text("Herunterladen")),
      TextButton(onPressed: () => Navigator.pop(context), child: Text("Schließen")),
    ],
  );
}
