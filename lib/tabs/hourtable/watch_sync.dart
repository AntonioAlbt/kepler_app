// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2026 Jakob Krause

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

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kepler_app/libs/logging.dart';

// Anstoß für die Übertragung der Plandaten an die Apple Watch. Die eigentliche Arbeit macht
// ios/Runner/WatchSyncBridge.swift - hier wird nur ausgelöst, sobald sich die Widget-Daten
// geändert haben.

const _channel = MethodChannel("kepler_app/watch_sync");

Timer? _debounce;

/// Schickt den aktuellen Stand aus der App-Group nach [delay] an die Uhr.
///
/// Entprellt, weil die Widget-Daten in kurzer Folge mehrfach geschrieben werden können (z.B. App-Start
/// und kurz danach Öffnen von "Dein Stundenplan", oder eine geänderte Planauswahl, während noch eine
/// Aktualisierung läuft - siehe updateIOSWidgetData in widget_data.dart). Ohne Entprellung ginge dann
/// mehr als eine Übertragung raus - die Uhr hat dafür nur ein begrenztes Tagesbudget. Unveränderte
/// Daten schickt die Bridge (WatchSyncBridge.swift) ohnehin nicht erneut.
///
/// Nur für die laufende App geeignet: Im Hintergrund-Task endet die Ausführung vor Ablauf des
/// Timers, dort [syncWatchNow] verwenden.
///
/// Schlägt nie mit einer Exception fehl: Auf anderen Plattformen als iOS passiert nichts, ein
/// fehlender Kanal oder eine nicht erreichbare Uhr stören den Aufrufer nicht.
void syncWatchSoon({Duration delay = const Duration(seconds: 2)}) {
  if (!Platform.isIOS) return;
  _debounce?.cancel();
  _debounce = Timer(delay, () => syncWatchNow());
}

/// Wie [syncWatchSoon], aber sofort und abwartbar - z.B. für den Hintergrund-Task. Eine noch
/// ausstehende entprellte Übertragung wird dabei verworfen, weil sie nichts Neueres schicken würde.
///
/// Gibt `true` zurück, wenn die Bridge die Übertragung angenommen hat oder sie übersprungen hat, weil
/// die Uhr den Stand schon hat (Antwort `skipped: unchanged`). `false` bei jedem Fehlergrund (`reason`).
Future<bool> syncWatchNow() async {
  if (!Platform.isIOS) return false;
  _debounce?.cancel();
  _debounce = null;
  try {
    final result = await _channel.invokeMethod<dynamic>("syncNow");
    if (result is Map) {
      final ok = result["ok"] == true;
      if (!ok) logDebug("watch-sync", "nicht übertragen: ${result["reason"]}");
      return ok;
    }
    return false;
  } on MissingPluginException {
    // Kanal nicht registriert - z.B. in einer Engine ohne die Bridge. Kein Fehlerfall.
    return false;
  } catch (e, s) {
    logCatch("watch-sync", "Fehler beim Übertragen an die Uhr: $e", s);
    return false;
  }
}
