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

import 'package:flutter/material.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/main.dart';
import 'package:provider/provider.dart';

/// argument priority: text+error -> textGen+error -> child
void showSnackBar({ String? text, bool error = false, Widget? child, String Function(bool sie)? textGen, bool clear = false, Duration duration = const Duration(seconds: 4) }) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    showSnackBarDirectly(text: text, error: error, child: child, textGen: textGen, clear: clear, duration: duration);
  });
}

void showSnackBarDirectly({ String? text, bool error = false, Widget? child, String Function(bool sie)? textGen, bool clear = false, Duration duration = const Duration(seconds: 4) }) {
  final msgr = ScaffoldMessenger.of(globalScaffoldContext);
  if (clear) msgr.clearSnackBars();
  msgr.showSnackBar(
    SnackBar(
      content: Builder(
        builder: (context) {
          // use the global scaffold context because this might be used by other pages
          final prefs = Provider.of<Preferences>(globalScaffoldContext, listen: false);
          final errorStyle = TextStyle(color: (prefs.darkTheme) ? Colors.redAccent.shade700 : Colors.redAccent.shade200);
          if (text != null) {
            return Text(
              text,
              style: (error) ? errorStyle : null,
            );
          } else if (textGen != null) {
            return Text(
              textGen(prefs.preferredPronoun == Pronoun.sie),
              style: (error) ? errorStyle : null,
            );
          } else if (child != null) {
            return child;
          } else {
            return const Text("Hallo :)"); // hallo :)
          }
        }
      ),
      duration: duration,
    ),
  );
}
