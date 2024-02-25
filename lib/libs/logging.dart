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

import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileOutput extends LogOutput {
  final String filePath;
  FileOutput(this.filePath);

  File? file;

  @override
  Future<void> init() async {
    super.init();
    file = File(filePath);
  }

  @override
  void output(OutputEvent event) async {
    if (file != null) {
      for (var line in event.lines) {
        await file?.writeAsString("${line.toString()}\n", mode: FileMode.writeOnlyAppend);
      }
    } else {
      for (var line in event.lines) {
        // ignore: avoid_print
        print(line);
      }
    }
  }
}

class CustomPrinter extends LogPrinter {
  static final levelPrefixes = {
    Level.trace: '[T]',
    Level.debug: '[D]',
    Level.info: '[I]',
    Level.warning: '[W]',
    Level.error: '[E]',
    Level.fatal: '[FATAL]',
  };

  @override
  List<String> log(LogEvent event) {
    var messageStr = _stringifyMessage(event.message);
    var errorStr = event.error != null ? '  ERROR: ${event.error}${event.stackTrace ?? ""}' : '';
    return ['[${logDateFormat.format(event.time)}] ${levelPrefixes[event.level]} $messageStr$errorStr'];
  }

  String _stringifyMessage(dynamic message) {
    final finalMessage = message is Function ? message() : message;
    if (finalMessage is Map || finalMessage is Iterable) {
      var encoder = const JsonEncoder.withIndent(null);
      return encoder.convert(finalMessage);
    } else {
      return finalMessage.toString();
    }
  }
}

final logDateFormat = DateFormat("dd.MM.yyyy HH:mm");

class KeplerLogging {
  static const logDir = "logs";
  static const logFileEnding = ".log";

  static Logger? logger;
  static DateTime? _fileUpdated;

  static void log({String? subTag, required Level level, required String message}) {
    if (!loggingEnabled) {
      if (kDebugMode) print("ignored log (logging disabled): $level - ${"${subTag != null ? "($subTag) " : ""}$message"}");
      return;
    }

    logger?.log(level, "${subTag != null ? "($subTag) " : ""}$message");

    if (_fileUpdated?.day != DateTime.now().day) initLogging();
  }

  static final fnDateFormat = DateFormat("dd_MM_yyyy");
  static Future<void> initLogging() async {
    final dir = await getPlatformSpecificLoggingDir();
    await dir.create(recursive: true);
    
    if (!loggingEnabled) return;

    final file = File("${dir.absolute.path}/${fnDateFormat.format(DateTime.now())}$logFileEnding");
    try {
      await file.create(exclusive: true);
      await file.writeAsString("Log erstellt: ${logDateFormat.format(DateTime.now())}\n");
    } on PathExistsException catch (_) {}
    logger = Logger(
      printer: CustomPrinter(),
      output: FileOutput(file.absolute.path),
      filter: ProductionFilter(),
      level: Level.debug,
    );
    _fileUpdated = DateTime.now();
  }

  static Future<Directory> getPlatformSpecificLoggingDir() async {
    return Directory("${await appDataDirPath}/$logDir");
  }

  static DateTime getDateFromFileName(String fileName) => fnDateFormat.parse(fileName.substring(0, fileName.length - logFileEnding.length + 1));

  static String fileName(File file) => file.path.split("/").last;
  static DateTime getDateFromFile(File file) => getDateFromFileName(fileName(file));

  static Future<List<File>> getAllLogFiles() async {
    final out = <File>[];
    for (final f in await (await getPlatformSpecificLoggingDir()).list().toList()) {
      if ((await f.stat()).type == FileSystemEntityType.file) out.add(File(f.absolute.path));
    }
    return out;
  }

  static Future<List<DateTime>> deleteLogsOlderThan(DateTime time) async {
    final deleted = <DateTime>[];
    for (final file in await getAllLogFiles()) {
      final date = getDateFromFile(file);
      if (date.isBefore(time)) {
        await file.delete();
        deleted.add(date);
      }
    }
    return deleted;
  }

  static void registerFlutterErrorHandling() {
    FlutterError.onError = (error) {
      logCatch("flutter-error", error.exception, error.stack ?? StackTrace.empty);
      FlutterError.presentError(error);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      logCatch("platform-dispatcher-error", error, stack);
      if (!loggingEnabled) debugPrintStack(label: error.toString(), stackTrace: stack);
      return true;
    };
  }
}

void logDebug(String? subTag, String message) => KeplerLogging.log(
  level: Level.debug,
  subTag: subTag,
  message: message,
);
void logInfo(String? subTag, String message) => KeplerLogging.log(
  level: Level.info,
  subTag: subTag,
  message: message,
);
void logWarn(String? subTag, String message) => KeplerLogging.log(
  level: Level.warning,
  subTag: subTag,
  message: message,
);
void logError(String? subTag, String message) => KeplerLogging.log(
  level: Level.error,
  subTag: subTag,
  message: message,
);
String limitStringLength(String input, int maxLength, [String? trailing]) => input.length > maxLength ? input.substring(0, maxLength) + (trailing ?? "") : input;
void logCatch(String? subTag, Object error, StackTrace stack) => KeplerLogging.log(
  level: Level.error,
  subTag: subTag,
  message: limitStringLength("$error:\n$stack", 5000, "..."),
);

Widget logViewerPageBuilder(BuildContext context) {
  return const LogListViewerPage();
}

class LogListViewerPage extends StatefulWidget {
  const LogListViewerPage({super.key});

  @override
  State<LogListViewerPage> createState() => _LogListViewerPageState();
}

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

Widget Function(BuildContext) logViewBuilder(FileSystemEntity file) => (context) => LogViewPage(File(file.absolute.path));

RegExp logPiece = RegExp(r"{(.*?)}");
String parseLog(String input) {
  final lines = input.split("\n");
  return lines.map((line) {
    final parsed = logPiece.allMatches(line).map((e) => e.group(1)!).toList();
    if (parsed.length == 5) {
      return "[${parsed[3]}] (${parsed[0]} - ${parsed[1]}) [${parsed[4]}]:\n${parsed[2]}";
    } else {
      return line;
    }
  }).join("\n");
}

class LogViewPage extends StatefulWidget {
  final File logFile;

  const LogViewPage(this.logFile, {super.key});

  @override
  State<LogViewPage> createState() => _LogViewPageState();
}

class _LogViewPageState extends State<LogViewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Aufzeichnung vom ${_outDF.format(KeplerLogging.getDateFromFile(widget.logFile))}")),
      body: Column(
        children: [
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () async {
                  Clipboard.setData(ClipboardData(text: await widget.logFile.readAsString()));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kopiert."), duration: Duration(seconds: 1)));
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
                                await Share.shareXFiles([XFile(path, mimeType: "text/plain")]);
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
                        parseLog(snapshot.data ?? "keine Daten"),
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
}
