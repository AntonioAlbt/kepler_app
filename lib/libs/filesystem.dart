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

import 'dart:convert';
import 'dart:io';

import 'package:kepler_app/libs/logging.dart';
import 'package:path_provider/path_provider.dart';

/// für Dateien, die auf Android durch Auswählen von "Cache leeren" vom Benutzer gelöscht werden können
Future<String> get cacheDirPath async => (await getApplicationCacheDirectory()).path;
/// für Benutzerdaten
Future<String> get userDataDirPath async => (await getApplicationDocumentsDirectory()).path;
/// für generelle App-Daten
Future<String> get appDataDirPath async => (await getApplicationSupportDirectory()).path;

/// Hilfsfunktionen für verschiedene Dateiaktionen

Future<bool> fileExists(String fn) => File(fn).exists();

/// Binärdaten in Datei schreiben
Future<bool> writeFileBin(String fn, List<int> data) async {
  final file = File(fn);
  try {
    final sink = file.openWrite();
    sink.add(data);
    sink.close();
    return true;
  } catch (e, s) {
    logDebug("filesystem", "$e:\n$s");
    return false;
  }
}
/// String in Datei schreiben
Future<bool> writeFile(String fn, String data) => writeFileBin(fn, utf8.encode(data));

/// Binärdaten aus Datei lesen
Future<List<int>?> readFileBin(String fn) async {
  if (!(await fileExists(fn))) return null;
  final file = File(fn);
  try {
    return await file.readAsBytes();
  } catch (e, s) {
    logDebug("filesystem", "$e:\n$s");
    return null;
  }
}
/// String aus Datei lesen
Future<String?> readFile(String fn) async {
  final raw = await readFileBin(fn);
  if (raw == null) return null;
  return utf8.decode(raw);
}
