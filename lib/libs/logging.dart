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
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:logger/logger.dart';

/// Output-Objekt, damit logger in eine Datei schreibt
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

/// eigenes Objekt, damit logger mit dem gewünschten Format Logs ausgibt
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

/// schönes, typisch deutsches Datumsformat
final logDateFormat = DateFormat("dd.MM.yyyy HH:mm");

/// statische Klasse, die für Logging in der Kepler-App zuständig ist
class KeplerLogging {
  /// Unterordner in App-Daten für Log-Dateien
  static const logDir = "logs";
  /// Dateiendung der Log-Dateien
  static const logFileEnding = ".log";

  static Logger? logger;
  static DateTime? _fileUpdated;

  /// Wrapper für logger.log, damit Deaktivieren berücksichtigt werden kann (und für subTag-Support)
  static void log({String? subTag, required Level level, required String message}) {
    if (!loggingEnabled) {
      if (kDebugMode) print("ignored log (logging disabled): $level - ${"${subTag != null ? "($subTag) " : ""}$message"}");
      return;
    }

    logger?.log(level, "${subTag != null ? "($subTag) " : ""}$message");

    /// wenn sich der Tag ändert, neue Log-Datei erstellen
    if (_fileUpdated?.day != DateTime.now().day) initLogging();
  }

  /// Datumsformat für Dateiname (wird auch zum Parsen verwendet)
  /// 
  /// damit typischer Dateiname: 01_01_2024.log
  static final fnDateFormat = DateFormat("dd_MM_yyyy");
  /// initialisiert alle nötigen Dinge für Logging, sollte in `main()` vor `runApp` aufgerufen werden
  /// 
  /// muss beliebig oft aufgerufen werden können
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

  /// Datum des Logs aus Dateiname entnehmen
  static DateTime getDateFromFileName(String fileName) => fnDateFormat.parse(fileName.substring(0, fileName.length - logFileEnding.length + 1));

  static String fileName(File file) => file.path.split("/").last;
  static DateTime getDateFromFile(File file) => getDateFromFileName(fileName(file));

  /// alle aktuell existierenden Log-Dateien abfragen
  static Future<List<File>> getAllLogFiles() async {
    final out = <File>[];
    for (final f in await (await getPlatformSpecificLoggingDir()).list().toList()) {
      if ((await f.stat()).type == FileSystemEntityType.file) out.add(File(f.absolute.path));
    }
    return out;
  }

  /// Logs älter als ein bestimmtes Datum löschen
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

  /// in der Fehlerbehandlung von Flutter registrieren, damit auch Flutter-Fehler im Log aufgezeichnet werden können
  /// 
  /// da Fehler in der Fehlerbehandlung nicht von Flutter gefangen werden, sollte kein unendlicher Loop bei Fehlern
  /// in KeplerLogging entstehen
  static void registerFlutterErrorHandling() {
    FlutterError.onError = (error) {
      logCatch("flutter-error", error.exception, error.stack ?? StackTrace.empty);
      FlutterError.presentError(error);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      logCatch("platform-dispatcher-error", error, stack);
      if (!loggingEnabled || kDebugMode) debugPrintStack(label: error.toString(), stackTrace: stack);
      return true;
    };
  }
}

// kürzere Hilfsfunktionen zum Loggen auf einem bestimmten Level

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
