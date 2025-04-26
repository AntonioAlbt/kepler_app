import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

/// erstellt ein LogListViewerPage-Widget
Widget logViewerPageBuilder(BuildContext context) {
  return const LogListViewerPage();
}

/// Übersichtsseite für alle aktuell existierenden Log-Dateien, bietet auch Option zum Löschen einzelner oder aller
class LogListViewerPage extends StatefulWidget {
  const LogListViewerPage({super.key});

  @override
  State<LogListViewerPage> createState() => _LogListViewerPageState();
}

/// Datumsformat für die ausgegebene Datei für den Benutzer
final _outDF = DateFormat("dd.MM.yyyy");
class _LogListViewerPageState extends State<LogListViewerPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Debug-Aufzeichnungen"), actions: [
        IconButton(
          onPressed: () {
            showDialog(context: context, builder: (ctx2) => AlertDialog(
              title: const Text("Wirklich alle löschen?"),
              content: const Text("Sollen alle Aufzeichnungen wirklich permanent gelöscht werden? Diese Aktion kann nicht rückgängig gemacht werden."),
              actions: [
                TextButton(onPressed: () async {
                  Navigator.pop(ctx2);
                  Navigator.pop(context);
                  await KeplerLogging.getAllLogFiles().then((files) => Future.wait(files.map((file) => file.delete())));
                }, child: const Text("Ja")),
                TextButton(onPressed: () {
                  Navigator.pop(ctx2);
                }, child: const Text("Nein, abbrechen")),
              ],
            ));
          },
          icon: const Icon(Icons.delete),
        ),
      ]),
      body: FutureBuilder(
        future: KeplerLogging.getAllLogFiles(),
        builder: (ctx1, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.connectionState == ConnectionState.done && !snapshot.hasData) return const Center(child: Text("Fehler beim Lesen."));
          return ListView(
            children: (snapshot.data!..sort((a, b) => KeplerLogging.getDateFromFile(b).compareTo(KeplerLogging.getDateFromFile(a)))).map((e) => ListTile(
              title: Text("Debug-Aufzeichnungen vom ${_outDF.format(KeplerLogging.getDateFromFile(e))}"),
              subtitle: FutureBuilder(
                future: e.readAsLines(),
                builder: (ctx, snapshot) {
                  if (snapshot.hasData) {
                    return Text("${snapshot.data!.length} Zeile${snapshot.data!.length == 1 ? "" : "n"}");
                  } else {
                    return const Text("... Zeilen");
                  }
                },
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => showDialog(context: ctx1, builder: (ctx2) => AlertDialog(
                  title: const Text("Wirklich löschen?"),
                  content: Text("Soll die Datei vom ${_outDF.format(KeplerLogging.getDateFromFile(e))} wirklich permanent gelöscht werden? Diese Aktion kann nicht rückgängig gemacht werden."),
                  actions: [
                    TextButton(onPressed: () {
                      e.delete();
                      Navigator.pop(ctx2);
                      Navigator.pop(context);
                    }, child: const Text("Ja")),
                    TextButton(onPressed: () {
                      Navigator.pop(ctx2);
                    }, child: const Text("Nein, abbrechen")),
                  ],
                )),
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: logViewBuilder(e))),
            )).toList(),
          );
        },
      ),
    );
  }
}

/// erstellt einen Builder für eine LogViewPage für eine bestimmte Log-Datei
Widget Function(BuildContext) logViewBuilder(FileSystemEntity file) => (context) => LogViewPage(File(file.absolute.path));

/// Ansichtsseite für eine Log-Datei, mit Optionen zum Kopieren, Teilen oder Hochladen auf LogUp
class LogViewPage extends StatefulWidget {
  final File logFile;

  const LogViewPage(this.logFile, {super.key});

  @override
  State<LogViewPage> createState() => _LogViewPageState();
}

class _LogViewPageState extends State<LogViewPage> {
  bool _logUpHostSet = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Aufzeichnung vom ${_outDF.format(KeplerLogging.getDateFromFile(widget.logFile))}")),
      body: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  Clipboard.setData(ClipboardData(text: await widget.logFile.readAsString()));
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Kopiert."), duration: Duration(seconds: 1)));
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(flex: 0, child: Text("Kopieren")),
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.copy, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Sicher?"),
                        content: const Text("Soll wirklich alles geteilt werden? Es könnten persönliche Informationen enthalten sein, die Ausgabe muss vorher überprüft werden!"),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Future<String> copyFile() async {
                                final oldDir = "${(await getTemporaryDirectory()).absolute.path}/share";
                                await Directory(oldDir).create(recursive: true);
                                final path = "$oldDir/Kepler-App-Log-${widget.logFile.path.split("/").last.replaceAll(".log", "")}.txt";
                                await widget.logFile.copy(path);
                                return path;
                              }
                              copyFile().then((path) async {
                                // ignore: use_build_context_synchronously
                                await SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: "text/plain")], sharePositionOrigin: Rect.fromLTWH(0, 0, MediaQuery.of(this.context).size.width, MediaQuery.of(this.context).size.height / 2)));
                                return path;
                              }).then((path) => File(path).delete());
                              Navigator.pop(context);
                            },
                            child: const Text("Ja, teilen"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Abbrechen"),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(flex: 0, child: Text("Datei teilen")),
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.share, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ElevatedButton(
                  onPressed: _logUpHostSet ? () {
                    showSnackBar(text: "Verfügbarkeit wird geprüft...", duration: const Duration(seconds: 30));
                    _checkLogupAvailability().then((avail) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(globalScaffoldContext).clearSnackBars();
                      if (!mounted) return;
                      if (!avail) {
                        showDialog(context: this.context, builder: (ctx) => AlertDialog(
                          title: Text("Nicht verfügbar"),
                          content: Text("Die Verbindung mit LogUp ist fehlgeschlagen. Bitte später erneut probieren."),
                        ));
                        return;
                      }
                      showDialog(context: this.context, builder: (_) => LogUpDialog(logFile: widget.logFile));
                    });
                  } : null,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(flex: 0, child: Text("Hochladen")),
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.upload, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: FutureBuilder(
                future: widget.logFile.readAsString(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.connectionState == ConnectionState.done && !snapshot.hasData) return const Center(child: Text("Fehler beim Lesen."));
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: SelectableText(
                        snapshot.data ?? "keine Daten",
                      ),
                    ),
                  );
                },
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
    _checkLogupAvailability();
    _logUpHostSet = Provider.of<Preferences>(context, listen: false).logUpHost != null;
  }

  Future<bool> _checkLogupAvailability() async {
    final host = Provider.of<Preferences>(context, listen: false).logUpHost;
    if (host != null) {
      try {
        return await http.get(Uri(scheme: "https", host: host, path: "/api/ping")).then((resp) {
          final data = jsonDecode(resp.body);
          if (data["service"] == "logup" && mounted) {
            return true;
          }
          return false;
        });
      } on Exception catch (e, s) {
        logCatch("logup-avail", e, s);
        return false;
      }
    } else {
      return false;
    }
  }
}

/// AlertDialog, der sich um das Hochladen einer Datei auf den ausgewählten LogUp-Server kümmert
/// 
/// LogUp-Server-Code ist auch auf GitHub: https://github.com/VLANT-Studios/VLANT-LogUp
class LogUpDialog extends StatefulWidget {
  final File logFile;

  const LogUpDialog({super.key, required this.logFile});

  @override
  State<LogUpDialog> createState() => _LogUpDialogState();
}

class _LogUpDialogState extends State<LogUpDialog> {
  late TextEditingController _nameController;
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final host = Provider.of<Preferences>(context, listen: false).logUpHost;
    final sie = Provider.of<Preferences>(context, listen: false).preferredPronoun == Pronoun.sie;
    return AlertDialog(
      title: Text("Auf VLANT-LogUp hochladen"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Indem ${sie ? "Sie Ihre" : "Du Deine"} Aufzeichnungen sicher auf $host ${sie ? "hochladen" : "hochlädst"}, kann nur der Betreiber direkt darauf zugreifen."),
          Text("Damit ${sie ? "stimmen Sie" : "stimmst Du"} den Datenschutzbedingungen auf https://$host/datenschutz zu."),
          Text("${sie ? "Sie können" : "Du kannst"} den Aufzeichnungen optional einen Namen geben, damit der Betreiber sie leichter finden kann."),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Name der Aufzeichnung (optional)"
              ),
              controller: _nameController,
            ),
          ),
          if (_uploading) Padding(
            padding: const EdgeInsets.all(4),
            child: LinearProgressIndicator(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () {
          setState(() {
            _uploading = true;
          });
          _uploadLog(host, _nameController.text != "" ? _nameController.text : null).then((token) {
            if (token == "ratelimit") {
              if (!mounted) return;
              showDialog(context: this.context, builder: (ctx) => AlertDialog(
                content: Text("Zu viele Aufzeichnungen hochgeladen. Bitte in einer Stunde nochmal probieren."),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Schließen")),
                ],
              ));
              Navigator.pop(this.context);
              return;
            }
            if (!mounted) return;
            showDialog(context: this.context, builder: (ctx) => AlertDialog(
              title: Text("Erfolgreich hochgeladen."),
              content: Text("Die Aufzeichnungen wurden erfolgreich hochgeladen.\n\nDiese ID sollte an den Betreiber weitergegeben werden: $token"),
              actions: [
                TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: token)), child: Text("ID kopieren")),
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Schließen")),
              ],
            )).then((_) {
              if (mounted) Navigator.pop(this.context);
            });
          }).catchError((err) {
            logCatch("logup-up", err, StackTrace.current);
            showSnackBar(text: "Fehler beim Hochladen.");
            if (!mounted) return;
            Navigator.pop(this.context);
          });
        }, child: Text("Jetzt hochladen")),
        TextButton(onPressed: () {
          Navigator.pop(context);
        }, child: Text("Abbrechen")),
      ],
    );
  }

  Future<String> _uploadLog(String? host, String? name) async {
    final pi = await PackageInfo.fromPlatform();
    final res = await http.post(Uri.parse("https://$host/api/upload"), body: jsonEncode({
      "content": await widget.logFile.readAsString(),
      "app_ver": "${pi.version}+${pi.buildNumber}",
      if (name != null) "name": name,
    }), headers: { "content-type": "application/json" });
    if (res.statusCode == 429) return "ratelimit";
    return jsonDecode(res.body)["token"];
  }

  @override
  void initState() {
    _nameController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
