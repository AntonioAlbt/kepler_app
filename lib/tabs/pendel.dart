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
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/widgets.dart';
import 'package:kepler_app/rainbow.dart';
import 'package:provider/provider.dart';

/// Link zu einer Webseite mit mehr Infos zum Pendel
const pendelInfoUrl = "https://pendel.vlant.de";
/// Link zur Daten-API vom Pendel
const pendelDataUrl = "https://pendel.vlant.de/logging";

/// globaler Key für Tab zum Aktualisieren in NavAction
final pendelInfoTabKey = GlobalKey<_PendelInfoTabState>();

/// Funktion für NavAction zum Aktualisieren
void pendelInfoRefreshAction() {
  pendelInfoTabKey.currentState?._load();
}

/// Tab für Datenanzeige von Datenerfassung des Foucaultschen Pendels im JKG
/// (Pendel gebaut und programmiert von Vlad H., 2022-24)
/// - Anzeige der Daten mit Text
/// - Darstellung der aktuellen Rotation des Pendels mit Strich über "Tischplatte" (Modellierung des Aufbaus)
/// - Farbanimation auf Strich, etwa so schnell, wie echtes Pendel schwingt (natürlich nicht echt synchron)
class PendelInfoTab extends StatefulWidget {
  PendelInfoTab() : super(key: pendelInfoTabKey);

  @override
  State<PendelInfoTab> createState() => _PendelInfoTabState();
}

final pendelDateFormat = DateFormat("dd.MM., HH:mm", "de-DE");

/// formatiere eine potentielle Nummer mit verschiedenen Optionen
/// - precision: wie viele Nachkommastellen maximal angezeigt werden
/// - suffix: was soll danach angehangen werden
/// - orElse: was soll zurückgegeben werden, wenn num == null ist
String formatForDisplay(double? num, int precision, [String? suffix, String? orElse])
  => num != null ? ((num * pow(10, precision)).roundToDouble() / pow(10, precision)).toString().replaceAll(".", ",") + (suffix ?? "") : orElse ?? "-";

class _PendelInfoTabState extends State<PendelInfoTab> with SingleTickerProviderStateMixin {
  /// hier war ich extrem inkonsequent mit den privaten Variablen (mit "_"), ist aber auch egal weil eh nie ein
  /// anderes Widget auf den State zugreift / zugreifen kann
  bool _loading = false, dataAvailable = false;
  /// Werte werden automatisch in diese Variablen geladen
  double? cpu, ram, angle, period;
  DateTime? lastUpdate;

  late final AnimationController _controller;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (!dataAvailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Selector<Preferences, bool>(
            selector: (_, prefs) => prefs.preferredPronoun == Pronoun.sie,
            builder: (context, sie, _) {
              return Text("Fehler beim Abfragen der Daten. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?");
            }
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text("Die aktuellen Daten des Foucaultschen Pendels an unserer Schule:", style: Theme.of(context).textTheme.bodyLarge),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("Letzte Aktualisierung: ${lastUpdate != null ? pendelDateFormat.format(lastUpdate!) : "unbekannt"}"),
            ),
            /// Server ist manchmal offline, dann wird länger nichts aktualisiert -> Hinweis wird angezeigt
            if (lastUpdate != null && lastUpdate!.difference(DateTime.now()).abs().inHours >= 4) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Card(
                color: hasDarkTheme(context) ? Colors.red.shade800 : Colors.red,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.white),
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text(
                            "Die Daten wurden schon länger nicht mehr aktualisiert, sie sind also wahrscheinlich nicht aktuell.",
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            /// modellhafte Darstellung der Pendelschwingung über Tisch, so ähnlich wie es in echt aus Vogelperspektive
            /// aussehen würde
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
                child: Column(
                  children: [
                    /// Seitenverhältnisse sollten etwa so sein wie der echte Tisch
                    SizedBox(
                      height: 200,
                      child: Stack(
                        alignment: AlignmentDirectional.center,
                        children: [
                          // Container(
                          //   decoration: BoxDecoration(
                          //     shape: BoxShape.circle,
                          //     color: Colors.blue.shade100,
                          //   ),
                          //   width: 250,
                          //   height: 250,
                          // ),
                          RainbowWrapper(
                            builder: (context, color) {
                              final bgCol = hasDarkTheme(context) ? colorWithLightness(Colors.grey.shade900, .2) : Colors.grey.shade300;
                              return Container(
                                decoration: BoxDecoration(
                                  color: color != null ? Color.alphaBlend(color.withOpacity(.25), bgCol) : bgCol,
                                ),
                                width: 350,
                                height: 200,
                              );
                            }
                          ),
                          SizedBox(
                            width: 300,
                            /// automatische Generation einer gestrichelten Linie als Mittellinie
                            /// (hab ich glaube ich irgendwo auf StackOverflow gefunden)
                            child: LayoutBuilder(
                              builder: (BuildContext context, BoxConstraints constraints) {
                                final boxWidth = constraints.constrainWidth();
                                const dashWidth = 5.0;
                                const dashHeight = 3.0;
                                final dashCount = (boxWidth / (2 * dashWidth)).floor();
                                return Flex(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  direction: Axis.horizontal,
                                  children: List.generate(dashCount, (_) {
                                    return SizedBox(
                                      width: dashWidth,
                                      height: dashHeight,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(color: hasDarkTheme(context) ? Colors.grey.shade700 : Colors.grey),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ),
                          Center(
                            child: Transform.rotate(
                              // + 90 is needed to change 0° to mean horizontal line
                              /// krasse Umrechnung von Grad in Radian (vielleicht hätte es auch eine Funktion von Dart
                              /// gegeben, aber naja)
                              angle: (pi / 180.0) * ((angle ?? 0) + 90),
                              child: AnimatedBuilder(
                                animation: _controller,
                                builder: (context, _) {
                                  return Rainbow2Wrapper(
                                    variant2: RainbowVariant.dark,
                                    builder: (context, color, color2) {
                                      return Container(
                                        // color: hasDarkTheme(context) ? Colors.blue.shade300 : Colors.blue.shade800,
                                        decoration: BoxDecoration(
                                          /// Animation von Strich entweder Blau oder mit zwei Regenbogen-Varianten
                                          gradient: LinearGradient(
                                            stops: [0, max(0, _controller.value - .3), _controller.value, _controller.value + .3, 2],
                                            begin: AlignmentDirectional.topCenter,
                                            end: AlignmentDirectional.bottomCenter,
                                            colors: (color == null || color2 == null)
                                                    ? [
                                                        Colors.blue.shade300,
                                                        Colors.blue.shade300,
                                                        Colors.blue.shade900,
                                                        Colors.blue.shade300,
                                                        Colors.blue.shade300
                                                      ]
                                                    : [color, color, color2, color, color],
                                          ),
                                        ),
                                        width: 5,
                                        height: 190,
                                      );
                                    }
                                  );
                                }
                              ),
                            ),
                          ),
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: hasDarkTheme(context) ? Colors.white : Colors.black,
                              ),
                              width: 15,
                              height: 3,
                            ),
                          ),
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: hasDarkTheme(context) ? Colors.white : Colors.black,
                              ),
                              width: 3,
                              height: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: "Aktueller Pendel-Winkel: "),
                            TextSpan(
                              text: formatForDisplay(angle?.roundToDouble(), 0, " °", "unbekannt"),
                              style: angle != null ? const TextStyle(fontWeight: FontWeight.bold) : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: "Aktuelle Zeit pro voller Drehung: "),
                          TextSpan(
                            text: formatForDisplay(period, 2, " h", "unbekannt"),
                            style: period != null ? const TextStyle(fontWeight: FontWeight.bold) : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: OpenLinkButton(
                label: "Mehr Infos zum Pendel",
                link: pendelInfoUrl,
              ),
            ),
            /// Nur anzeigen, wenn Benutzer sehr technikinteressiert ist (weil sonst irrelevant)
            /// bzw. könnte auch auf Webseite eingesehen
            if (kDebugFeatures) Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text("Debug-Daten:\n  Systeminfo: CPU: ${formatForDisplay(cpu, 2, " %", "-")}, RAM: ${formatForDisplay(ram, 2, " %", "-")}"),
            ),
            if (kDebugFeatures && (lastUpdate?.year ?? 153000) < 2022) const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Hinweis: Test-Daten - Verbindung zum Server nicht möglich."),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3700));
    _controller.repeat(reverse: true);
    _autoReload();
  }

  void _autoReload() async {
    if (!mounted) return;
    _load();
    Future.delayed(const Duration(seconds: 30)).then((_) {
      _autoReload();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      dataAvailable = false;
    });

    final (date_, angle_, period_, cpu_, ram_) = await getPendelData();
    /// da sowieso am Ende setState aufgerufen wird, rufe ich es hier trotz der Veränderung der Feldern nicht auf
    /// (bei !mounted wird das Widget eh nicht mehr angezeigt)
    lastUpdate = date_; angle = angle_; period = period_; cpu = cpu_; ram = ram_;
    dataAvailable = angle != null;
    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }
}

/// Rückgabe-Daten: (Zuletzt aktualisiert, Winkel, Periodendauer, CPU %, RAM %)
Future<(DateTime?, double?, double?, double?, double?)> getPendelData() async {
  try {
    final res = jsonDecode((await http.get(Uri.parse(pendelDataUrl))).body);
    // the values should already be double-s, but just to be safe, convert them anyway
    // the api is sometimes unreliable
    /// - API gibt möglicherweise nur teilweise ungültige Daten zurück, also so viel wie möglich erfassen und anzeigen
    logDebug("pendel", "fetched pendel data from $pendelDataUrl");
    return (
      DateTime.tryParse(res["date"]?.toString() ?? "-")?.toLocal(),
      double.tryParse(res["angle"]?.toString() ?? "-"),
      double.tryParse(res["period"]?.toString() ?? "-"),
      double.tryParse(res["cpu"]?.toString() ?? "-"),
      double.tryParse(res["ram"]?.toString() ?? "-"),
    );
  } catch (e, s) {
    logCatch("pendel", e, s);
    if (kDebugFeatures) {
      /// Jahr muss bei Testdaten kleiner als 2022 sein
      return (DateTime(2020, 3, 11), 66.66, 31.2, 9.2314, 15.309);
    }
    // // can be simplified, but is better readable this way
    // dataAvailable = kDebugFeatures ? true : false;
    if (kDebugMode) print("$e - $s");
  }
  return (null, null, null, null, null);
}
