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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/state.dart';

/// der Ladebildschirm wird beim Start der App angezeigt und ist eine Animation des Logos der App (vereinfachtes
/// JKG-Logo), wie die drei Kreise größer werden und dann pulsieren
/// - zum Glück ist die Animation so einfach, dass sie direkt mit Flutter funktioniert und keine weitere Animations-
///   bibliothek benötigt
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

const _withBorder = true;
const _borderWidth = 2.0;

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _circle1AnimContr;
  late AnimationController _circle2AnimContr;
  late AnimationController _circle3AnimContr;
  late AnimationController _textAnimContr;

  Widget? _switcherChild;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /// auf Ladebildschirm auf Beta-Version aufmerksam machen
        if (kIsBetaVersion) Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadiusDirectional.circular(16),
              color: Colors.red,
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text("BETA-VERSION", style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
        /// die drei Kreise mit den entsprechenden Farben passend skalieren und anpassen
        SizedBox(
          width: 300,
          height: 350,
          child: Stack(
            children: [
              Positioned(
                left: 50,
                child: ScaleTransition(
                  scale: _circle1AnimContr,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: keplerColorYellow,
                      border:
                          (_withBorder) ? Border.all(width: _borderWidth) : null,
                    ),
                    width: 200,
                    height: 200,
                  ),
                ),
              ),
              Positioned(
                top: 100,
                left: 160,
                child: ScaleTransition(
                  scale: _circle3AnimContr,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: keplerColorBlue,
                      border:
                          (_withBorder) ? Border.all(width: _borderWidth) : null,
                    ),
                    width: 115,
                    height: 115,
                  ),
                ),
              ),
              Positioned(
                top: 110,
                left: 30,
                child: ScaleTransition(
                  scale: _circle2AnimContr,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: keplerColorOrange,
                      border:
                          (_withBorder) ? Border.all(width: _borderWidth) : null,
                    ),
                    width: 140,
                    height: 140,
                  ),
                ),
              ),
              /// falls die App "sehr lange" lädt, Text und evtl. Knopf zum Schließen anzeigen
              Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _textAnimContr,
                      child: const Text(
                        "Kepler-App lädt... Bitte warten.",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _switcherChild ?? Opacity(key: UniqueKey(), opacity: 0, child: ElevatedButton(onPressed: () {}, child: const Text(""))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    _circle1AnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _circle2AnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _circle3AnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _textAnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

    /// immer nach Beendigung der vorherigen Animation die nächste starten
    _circle1AnimContr.addListener(() {
      if (_circle1AnimContr.isCompleted) _circle2AnimContr.forward();
    });
    _circle2AnimContr.addListener(() {
      if (_circle2AnimContr.isCompleted) _circle3AnimContr.forward();
    });
    _circle3AnimContr.addListener(() {
      if (_circle3AnimContr.isCompleted) {
        /// nach kurzer Zeit pulsierende Animation starten
        Future.delayed(const Duration(milliseconds: 200)).then((_) {
          if (!mounted) return;
          _textAnimContr.repeat(reverse: true, period: const Duration(milliseconds: 700));

          _circle1AnimContr.dispose();
          _circle1AnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 700), upperBound: 1.1, lowerBound: 1);
          _circle1AnimContr.repeat(reverse: true);

          _circle2AnimContr.dispose();
          _circle2AnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 700), upperBound: 1.1, lowerBound: 1);
          _circle2AnimContr.repeat(reverse: true);

          _circle3AnimContr.dispose();
          _circle3AnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 700), upperBound: 1.1, lowerBound: 1);
          _circle3AnimContr.repeat(reverse: true);
          setState(() {});
        });
        /// auf iOS kann sich eine App nicht selbst schließen, also wird der Knopf dort nicht angezeigt
        if (Platform.isAndroid) {
          Future.delayed(const Duration(milliseconds: 2000)).then((_) {
            if (!mounted) return;
            setState(() {
              _switcherChild = ElevatedButton(
                onPressed: () {
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: hasDarkTheme(context) ? const Color.fromARGB(6, 15, 111, 190) : Colors.white),
                child: const Text("Schließen"),
              );
            });
          });
        }
        Future.delayed(const Duration(seconds: 14)).then((_) {
          if (!mounted) return;
          logWarn("loading", "LoadingError: long loading time, ~ 15s");
        });
        Future.delayed(const Duration(milliseconds: 24050)).then((_) {
          if (!mounted) return;
          logWarn("loading", "LoadingError: extremely long loading time, = 25s");
        });
      }
    });
    // _circle3AnimContr.addListener(() {
    //   if (_circle3AnimContr.isCompleted) _circle1AnimContr.forward();
    // });

    _circle1AnimContr.forward();

    super.initState();
  }

  @override
  void dispose() {
    _circle1AnimContr.dispose();
    _circle2AnimContr.dispose();
    _circle3AnimContr.dispose();
    _textAnimContr.dispose();
    super.dispose();
  }
}
