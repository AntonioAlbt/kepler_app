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

import 'package:flutter/foundation.dart';

/// Die Build-Konstanten, die hier definiert werden, können (wie in README.md) erklärt, beim Builden der App
/// von Flutter gesetzt werden, z.B.:
///   flutter build appbundle --dart-define=beta=true --dart-define=debug_features=false
/// 
/// Wenn nicht gesetzt, wird der Standardwert genommen (defaultValue).

/// soll der Text "BETA-VERSION" auf dem Ladebildschirm angezeigt werden
const kIsBetaVersion = bool.fromEnvironment("beta", defaultValue: kDebugMode);
/// sollen verschiedene Debug-Features aktiviert/angezeigt werden (siehe Verwendungen der Variable)
const kDebugFeatures = bool.fromEnvironment("debug_features", defaultValue: kDebugMode);
/// sollen jedes Mal beim Überprüfen auf neue Daten für Benachrichtigungen Test-Daten verwendet und als
/// Benachrichtigung angezeigt werden
const kDebugNotifData = bool.fromEnvironment("debug_notif_data", defaultValue: false);
/// sollen alle Änderungen an Login-Daten im Log aufgezeichnet werden
const kCredsDebug = bool.fromEnvironment("creds_debug", defaultValue: false);
