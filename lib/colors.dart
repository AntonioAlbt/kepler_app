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

import 'package:flutter/painting.dart';

/// Farben im kleinen JKG-Logo (favicon von kepler-chemnitz.de)

/// Gelbton
const keplerColorYellow = Color(0xFFfed44c);
/// Orangeton
const keplerColorOrange = Color(0xFFff7c00);
/// Blauton, Primärfarbe der App
const keplerColorBlue = Color(0xFF4a8aba);

/// damit die Farben auch als Hintergrundfarbe im Dark/Light Mode verwendet werden können, gibt es diese
/// Hilfsfunktion - mit sehr heller/sehr dunkler Helligkeit sind die Farben blasser und unscheinbarer
Color colorWithLightness(Color color, double lightness)
  => HSLColor.fromColor(color).withLightness(lightness).toColor();
