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
import 'package:kepler_app/rainbow.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';

/// eigentlich folgen alle Stundenplanseiten diesem Schema
/// 1. GlobalKey für navActions definieren
/// 2. RainbowWrapper in Stack für Hintergrund
/// 3. wichtigster Teil: StuPlanDisplay mit mode passend gesetzt

final allReplacesDisplayKey = GlobalKey<StuPlanDisplayState>();

/// wie der Name sagt, werden alle Vertretungen des Tages (alle Stunden mit Änderungen) nach Klasse sortiert
/// aufgelistet (wie Bildschirm im Foyer der Schule)
class AllReplacesPage extends StatelessWidget {
  const AllReplacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RainbowWrapper(builder: (_, color) => Container(color: color?.withValues(alpha: .5))),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: StuPlanDisplay(
            key: allReplacesDisplayKey,
            selected: "5 bis 12",
            mode: SPDisplayMode.allReplaces,
            showInfo: false,
          ),
        ),
      ],
    );
  }
}

void allReplacesRefreshAction() {
  allReplacesDisplayKey.currentState?.forceRefreshData();
}
