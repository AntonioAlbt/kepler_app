import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
    logger?.log(level, "${subTag != null ? "($subTag) " : ""}$message");

    if (_fileUpdated?.day != DateTime.now().day) initLogging();
  }

  static final fnDateFormat = DateFormat("dd_MM_yyyy");
  static Future<void> initLogging() async {
    final dir = await getPlatformSpecificLoggingDir();
    await dir.create(recursive: true);

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
    if (Platform.isAndroid) {
      return Directory("${(await getExternalStorageDirectory())!.absolute.path}/$logDir");
    } else if (Platform.isIOS) {
      return Directory("${(await getApplicationSupportDirectory()).absolute.path}/$logDir");
    } else {
      return Directory("/tmp/kepler_app/$logDir");
    }
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
void logCatch(String? subTag, Object error, StackTrace stack) => KeplerLogging.log(
  level: Level.error,
  subTag: subTag,
  message: "$error:\n$stack",
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
      appBar: AppBar(title: const Text("Debug-Aufzeichnungen")),
      body: FutureBuilder(
        future: KeplerLogging.getAllLogFiles(),
        builder: (context, snapshot) {
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
