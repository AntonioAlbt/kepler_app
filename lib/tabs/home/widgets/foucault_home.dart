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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';
import 'package:kepler_app/tabs/pendel.dart';
import 'package:provider/provider.dart';

/// Widget, was eine vereinfachte Darstellung des "Tisches" im Pendel-Tab anzeigt
class HomePendulumWidget extends StatelessWidget {
  /// Home-Widget-ID - muss mit der in home.dart übereinstimmen
  final String id;

  const HomePendulumWidget({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return HomeWidgetBase(
      id: id,
      color: hasDarkTheme(context) ? Colors.blue.shade800 : Colors.blue.shade300,
      title: const Text("Foucaultsches Pendel"),
      child: FutureBuilder(
        future: getPendelData(),
        builder: (context, datasn) {
          return FPDisplay(child: SizedBox(
            width: 175,
            height: 128,
            child: (datasn.connectionState == ConnectionState.done && datasn.data != null) ? Builder(
              builder: (context) {
                final (_, angle, _, _, _) = datasn.data!;
                return Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Flexible(
                      flex: 4,
                      /// einfach eine kleinere, nicht animierte Darstellung des Pendels als auf der Pendel-Seite
                      child: Stack(
                        alignment: AlignmentDirectional.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: hasDarkTheme(context) ? colorWithLightness(Colors.grey.shade900, .2) : Colors.grey.shade300,
                            ),
                            width: 175,
                            height: 100,
                          ),
                          SizedBox(
                            width: 175,
                            child: LayoutBuilder(
                              builder: (BuildContext context, BoxConstraints constraints) {
                                final boxWidth = constraints.constrainWidth();
                                const dashWidth = 3.0;
                                const dashHeight = 2.0;
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
                              angle: (pi / 180.0) * ((angle ?? 0) + 90),
                              child: Container(
                                height: 90,
                                width: 5,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: hasDarkTheme(context) ? Colors.white : Colors.black,
                              ),
                              width: 10,
                              height: 2,
                            ),
                          ),
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: hasDarkTheme(context) ? Colors.white : Colors.black,
                              ),
                              width: 2,
                              height: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text("Winkel: ${formatForDisplay(angle, 0, " °", "unbekannt")}"),
                      ),
                    ),
                  ],
                );
              }
            ) : const Center(child: CircularProgressIndicator()),
          ));
        }
      ),
    );
  }
}

/// FPDisplay = Foucaultsches Pendel Display
/// - zeigt, wider Erwarten, nicht den Pendelzustand, sondern alles außenrum (Link zur Webseite, Ladeanim., ...) an
/// 
/// Ich weiß auch ehrlich nicht, warum das als separates Widget verfügbar ist - es hat keinerlei andere Verwendung.
class FPDisplay extends StatelessWidget {
  /// Widget mit der tatsächlichen Darstellung des Pendels
  final Widget? child;
  /// wird aufgerufen, wenn der Benutzer die Daten aktualisieren will
  final VoidCallback? onRefresh;
  /// werden die Daten aktuell noch abgefragt
  final bool stillLoading;
  /// konnte sich mit dem Server verbunden werden
  final bool isOnline;
  const FPDisplay({super.key, required this.child, this.onRefresh, this.stillLoading = false, this.isOnline = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 0, left: 8, right: 8, bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: colorWithLightness(keplerColorOrange.withValues(alpha: .75), hasDarkTheme(context) ? .025 : .9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: () {
          Widget? child;
          if (stillLoading) {
            child = const Expanded(
              child: Center(
                child: Text(
                  "Lädt Daten...",
                  style: TextStyle(fontSize: 17),
                ),
              ),
            );
          } else if (this.child == null) {
            child = Expanded(
              child: Center(
                child: Text(
                  isOnline ? "Keine Daten verfügbar." : "Keine Verbindung zum Server.",
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 16, right: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [PageIDs.pendel];
                        },
                        child: const Row(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Text(
                                "Zu den Pendeldaten",
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Icon(Icons.open_in_new, size: 20),
                          ],
                        ),
                      ),
                      // const Spacer(),
                      // IconButton(
                      //   onPressed: onRefresh,
                      //   icon: const Icon(Icons.refresh, size: 20),
                      //   style: IconButton.styleFrom(padding: EdgeInsets.zero, visualDensity: const VisualDensity(horizontal: -4, vertical: -4)),
                      // ),
                    ],
                  ),
                ),
                Divider(
                  thickness: 1.5,
                  color: Colors.grey.shade700,
                ),
                this.child ?? Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12, right: 12, bottom: 8),
                    child: child,
                  ),
                ),
              ],
            ),
          );
        }()),
    );
  }
}
