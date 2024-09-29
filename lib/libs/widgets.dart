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
import 'package:kepler_app/libs/snack.dart';
import 'package:url_launcher/url_launcher.dart';

/// zwischen alle gegebenen Widgets einen Divider einschieben
List<Widget> separatedListViewWithDividers(List<Widget> children)
  => children.fold((0, <Widget>[]), (previousValue, element) {
    final (i, list) = previousValue;
    list.add(element);
    if (i != children.length - 1) list.add(const Divider());
    return (i + 1, list);
  }).$2;


/// Knopf mit mehr Optionen, der primär für das Öffnen eines Links verwendet werden sollte
class OpenLinkButton extends StatelessWidget {
  final String label;
  final String link;
  final Icon? infront;
  final Icon? trailing;
  final bool showTrailingIcon;
  const OpenLinkButton({
    super.key, required this.label, required this.link, this.infront, this.trailing, this.showTrailingIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication).catchError((_, __) {
          showSnackBar(text: "Fehler beim Öffnen.");
          return true;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (infront != null) Flexible(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: infront!,
            ),
          ),
          Flexible(flex: 0, child: Text(label)),
          if (showTrailingIcon) Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: trailing ?? const Icon(Icons.open_in_new, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
