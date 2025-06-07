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

import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';
import 'package:kepler_app/tabs/lernsax/lernsax.dart';
import 'package:provider/provider.dart';

/// sehr simples Widget - zeigt einen einzigen Knopf an, der einen LS-Autologin-Link öffnet
class HomeLSLinkWidget extends StatelessWidget {
  /// Home-Widget-ID - muss mit der in home.dart übereinstimmen
  final String id;

  const HomeLSLinkWidget({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return HomeWidgetBase(
      id: id,
      color: hasDarkTheme(context) ? colorWithLightness(Colors.green, .15) : Colors.green,
      title: const Text("LernSax öffnen"),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: hasDarkTheme(context) ? const Color.fromARGB(255, 10, 36, 11) : Colors.green.shade100, foregroundColor: hasDarkTheme(context) ? Colors.white : const Color.fromARGB(255, 20, 67, 23)),
        onPressed: (){
          final creds = Provider.of<CredentialStore>(context, listen: false);
          lernSaxOpenInBrowser(context, creds.lernSaxLogin!, creds.lernSaxToken!);
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text("Im Browser öffnen")),
            Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.open_in_new, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
