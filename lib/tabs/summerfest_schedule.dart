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

import 'dart:convert';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/colors.dart';
import 'package:drive_direct_download/drive_direct_download.dart';
import 'package:http/http.dart' as http;
import 'package:kepler_app/main.dart';
import 'package:provider/provider.dart';

/// Link zur (beliebig benannten) auf Google-Drive gespeicherten Datei Ablaufplan.json
const String _scheduleJsonUrl = "https://drive.google.com/file/d/1Z-WR9bkXmD6-EPEGZLFoNTZWjUualeWi/view?usp=drive_link";

/// Seite, welche den Ablaufplan lädt und anzeigt
class SummerFestSchedulePage extends StatefulWidget {
  const SummerFestSchedulePage({super.key});

  @override
  State<SummerFestSchedulePage> createState() => _SummerFestSchedulePageState();
}

class _SummerFestSchedulePageState extends State<SummerFestSchedulePage> {
  bool _loading = true;
  Map<String, dynamic>? _scheduleData;

  /// Der Hintergrund des Ablaufplans, zeigt die Uhrzeiten mit optischen Orientierungen an.
  /// Dafür wird in eine Spalte für jeden Zeitstempel ein Flexible mit der Uhrzeit und ein Divider als optische Trennung eingefügt.
  /// Am Ende wird erneut ein Flexible mit Uhrzeit eingefügt, aber ohne Divider, da am Ende.
  /// Wird das Widget in ein Parentwidget mit vorgegebener Höhe eingefügt, sind alle Zeitabschnitte automatisch gleich lang.
  Widget _buildBackground() {
    final cl = <Widget>[];
    final times = _scheduleData!["zeitstempel"].cast<String>();
    for (var i = 0; i < times.length - 1; i++) {
      cl.add(
        Flexible(
          child: SizedBox.expand(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(times[i].toString()),
            ),
          ),
        ),
      );
      cl.add(Divider(height: 0));
    }
    cl.add(
      Flexible(
        child: SizedBox.expand(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(times.last.toString()),
          ),
        ),
      ),
    );
    return Column(
      children: cl,
    );
  }

  /// Erstellt aus den Ablaufplandaten die Gesamtansicht der Boxen (Widget ScheduleBox),
  /// welche jeweils ein Ereignis verkörpern. Dabei wird wie beim Hintergrund ein
  /// Parentwidget mit vorgegebener Höhe angenommen, in welchem die
  /// Rechtecke automatisch die zeitlich richtige Höhe haben. Im Standardfall wird
  /// angenommen, dass die in der json-Datei vorgegebenen Flexible-Werte die Anzahl
  /// an Dritteln von Zeitschritten angeben, also für halbstündige Abschnitte
  /// steht ein Flexible-Wert von 1 für 10 min Länge.
  /// Damit muss natürlich beim Schreiben der Datei sichergestellt werden, dass
  /// es insgesamt pro Zeitstempel genau drei Flexibleeinheiten gibt.
  /// Die Drittelung ist aber keine feste Vorgabe, man kann natürlich auch nur zwei
  /// Flexeinheiten pro Zeitabschnitt angeben. Die Gesamtanzahl der Flexabschnitte
  /// sollte aber ein Vielfaches der Anzahl der Zeitabschnitte sein, sonst
  /// stimmen die Boxgrenzen nicht mit den Abschnitten überein.
  ///
  /// Der Ablaufplan wird von oben nach unten durch sogenannte LayoutChildren beschrieben.
  /// Von diesen gibt es die Typen 'horizontal' und 'vertikal'.
  /// Der Typ 'horizontal' beschreibt eine einfache Box, welche die komplette Breite
  /// des Ablaufplans einnimmt.
  /// Der Typ 'vertikal' beschreibt einen Abschnitt des Plans, welcher die komplette
  /// Breite in die vorgegebene Anzahl gleich breiter Spalten teilt. Innerhalb dieser
  /// Spalten werden wieder übereinander Boxen angeordnet.
  Widget _buildBoxLayout() {
    /// Einlesen des Layouts
    final layoutChildren = _scheduleData!["layout"] as List<dynamic>;
    var cl = <Widget>[];
    /// Für jeden Teil des Layouts
    for (final layoutChild in (layoutChildren).cast<Map<String, dynamic>>()) {
      if (layoutChild["typ"] == "horizontal") {
        cl.add(
          /// Hinzufügen einer Box zum Hauptlayout cl.
          /// Für die Beschriftung gibt es die Sonderzeichenkette '[BREAK]',
          /// mit welcher man manuell im Text einen optionalen Zeilenumbruch vorgeben kann.
          /// Die Zeichenkette wird mit dem Sonderzeichen '\u00AD' ersetzt, welche
          /// einen solchen Zeilenumbruch darstellt.
          /// Für die Farbe gibt es vorgegebene Farbstrings, welche über eine
          /// Funktion in echte Farbwerte umgewandelt werden.
          /// Flex gibt die relative Höhe vor.
          ScheduleBox(
            caption: ((layoutChild["balken"] as Map<String, dynamic>)["beschriftung"] as String).replaceAll('[BREAK]', '\u00AD'),
            color: _getColorFromString((layoutChild["balken"] as Map<String, dynamic>)["farbe"]),
            flex: (layoutChild["balken"] as Map<String, dynamic>)["länge"]),
        );
      }
      if (layoutChild["typ"] == "vertikal") {
        /// Sonst müsste es ein Vertikal-Layout sein.
        /// cl2 ist das Vertikallayyout.
        /// Die Spalten werden als cl3 iterativ erzeugt und zu cl2 hinzugefügt.
        var cl2 = <Widget>[];
        for (final column in (layoutChild["layout"] as Map<String, dynamic>)["spalten"].cast<List<dynamic>>()) {
          var cl3 = <Widget>[];
          for (var box in (column as List)) {
            cl3.add(
              ScheduleBox(
                caption: (box["beschriftung"] as String).replaceAll('[BREAK]', '\u00AD'),
                color: _getColorFromString(box["farbe"]),
                flex: (box["länge"]),
              ),
            );
          }
          cl2.add(
            Flexible(
              child: Column(
                children: cl3,
              ),
            ),
          );
        }
        cl.add(
          Flexible(
            flex: (layoutChild["layout"] as Map<String, dynamic>)["länge"],
            child: Row(
              children: cl2,
            ),
          ),
        );
      }
    }
    return Column(children: cl);
  }
  
  @override
  Widget build(BuildContext context) {
    /// Ladebildschirm
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text("Lädt Ablaufplan..."),
            ),
          ],
        ),
      );
    }
    /// Wenn nach dem Laden trotzdem keine Daten vorhanden sind, wird eine Fehlermeldung angezeigt
    if (_scheduleData == null) {
      return Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Fehler beim Abrufen des Ablaufplans.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: hasDarkTheme(context) ? Colors.red.shade300 : Colors.red.shade800),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                  });
                  _loadData();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                      child: Icon(Icons.refresh, size: 23),
                    ),
                    Text("Erneut versuchen"),
                  ],
                )
              ),
            ],
          ),
        ),
      );
    }

    /// Das Laden müsste jetzt erfolgreich abgeschlossen sein, jetzt werden die beiden Widgets erstellt.
    final backgroundWidget = _buildBackground();
    final scheduleWidget = _buildBoxLayout();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: hasDarkTheme(context)
                          ? Colors.black45
                          : Colors.grey.withValues(alpha: 0.5),
                      offset: const Offset(0,3),
                      spreadRadius: 5,
                      blurRadius: 7,
                    ),
                  ],
                  color: Theme.of(context).colorScheme.surface,
                ),
                margin: EdgeInsets.all(12),
                padding: EdgeInsets.fromLTRB(7, 6, 6, 7),
                width: double.infinity,
                /// Für das Anzeigen wird aus der Anzahl der Zeitstempel die notwendige
                /// Gesamthöhe berechnet. Diese bildet dan die Grundmaße für beide
                /// Widgets, welche mit einem Stack übereinandergelegt werden.
                child: SingleChildScrollView(
                  child: SizedBox(
                    height: (_scheduleData!["zeitstempel"].cast<String>() as List).length * 72.0,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        backgroundWidget,
                        Row(
                          children: [
                            SizedBox(
                              width: 48,
                            ),
                            Expanded(child: scheduleWidget),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              ),
            ),
            Text("Stand ${_scheduleData!["zuletzt_geändert"] as String} - Änderungen vorbehalten"),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Widgetinterne Logik für das Laden der Daten
  Future<void> _loadData() async {
    final data = await loadScheduleData();
    setState(() {
      _scheduleData = data;
      _loading = false;
    });
    if (data == null) {
      showSnackBar(textGen: (sie) => "Fehler beim Abrufen des Ablaufplans. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
    }
    return;
  }
}

/// Abrufen der Daten von Google Drive, diese werden dann in eine Map überführt
Future<Map<String, dynamic>?> loadScheduleData() async {
  final http.Response res;
  final String encodedScheduleJsonUrl = await DriveDirect.download(driveLink: _scheduleJsonUrl);
  try {
    res = await http.get(Uri.parse(encodedScheduleJsonUrl));
  } catch (e, s) {
    logCatch("summerfest-schedule-data", e, s);
    return null;
  }

  try {
    final scheduleData = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    logDebug("summerfest-schedule-data", "loaded data from ${res.request?.url.toString()} and got ${scheduleData.toString()}");
    return scheduleData;
  } catch (e, s) {
    logCatch("summerfest-schedule-data", e, s);
    return null;
  }
}

/// Widget, welche ein einzelnes Ereignis als Box im Layout darstellt.
/// Für die dynamische Höhe wird auf oberster Ebene ein Flexible zurückgegeben.
/// Wenn color = null ist die Box unsichtbar.
class ScheduleBox extends StatelessWidget {
  const ScheduleBox({super.key, required this.color, required this.flex, this.caption = ""});

  final Color? color;
  final int flex;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.fromLTRB(2,1,1,2),
        child: SizedBox.expand(
          child: (color != null) ?
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: color,
                  ),
                  child: Center(
                    child: Text(caption),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Funktion, welche für bestimmte, vorgegebenen Farben den zum Farbmodus passenden
/// Farbwert zurückgibt. Die vordefinierte Farbe 'unsichtbar' sowie unbekannte
/// Farben führen zu einer leeren Rückgabe, was ultimativ zu Platzhalterboxen
/// führt, also unsichtbaren Boxen:
Color? _getColorFromString(String colorString) {
  final bool darkTheme = Provider.of<Preferences>(globalScaffoldContext, listen: false).darkTheme;
  switch (colorString) {
    case "KeplerBlau": return colorWithLightness(keplerColorBlue, darkTheme ? .25 :.55);
    case "KeplerOrange": return colorWithLightness(keplerColorOrange, darkTheme ? .25 : .65);
    case "KeplerGelb": return darkTheme ? colorWithLightness(keplerColorYellow, .25) : keplerColorYellow;
    case "unsichtbar":
    default: return null;
  }
}