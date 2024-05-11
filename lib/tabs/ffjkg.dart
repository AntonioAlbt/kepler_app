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
import 'package:kepler_app/libs/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class FFJKGTab extends StatefulWidget {
  const FFJKGTab({super.key});

  @override
  State<FFJKGTab> createState() => _FFJKGTabState();
}

class _FFJKGTabState extends State<FFJKGTab> {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(
            "FFJKG - Freunde und Förderer des Johannes-Kepler-Gymnasiums",
            style: TextStyle(fontSize: 16),
          ),
          Text(
            "Die Veröffentlichung dieser App wurde vom FFJKG freundlicherweise unterstützt.",
          ),
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: OpenLinkButton(
              label: "Per Mail kontaktieren",
              link: "mailto:ffjkg@kepler-chemnitz.de",
              showTrailingIcon: false,
              infront: Icon(Icons.mail, size: 16),
            ),
          ),
          OpenLinkButton(
            label: "Mitglied werden!",
            link: "https://www.kepler-chemnitz.de/mitgliedsantrag/",
            infront: Icon(Icons.person, size: 18),
          ),
          Divider(),
          OpenLinkButton(
            label: "Ansprechpartner der Schule",
            link: "https://www.kepler-chemnitz.de/ansprechpartner/",
          ),
          OpenLinkButton(
            label: "Schließfach online bestellen",
            link: "https://www.kepler-chemnitz.de/foerderverein/schliessfach-online-bestellen/",
          ),
          OpenLinkButton(
            label: "Bestellung Hausaufgabenheft",
            link: "https://www.kepler-chemnitz.de/bestellung-hausaufgabenheft/",
          ),
          OpenLinkButton(
            label: "Weihnachtskonzert DVD bestellen",
            link: "https://www.kepler-chemnitz.de/unser-weihnachtskonzert-2023-in-der-st-petrikirche-chemnitz-auf-dvd/",
          ),
        ],
      ),
    );
  }
}

Future<bool> ffjkgSchoolReprOpen(BuildContext _) async {
  launchUrl(
    Uri.parse("https://www.kepler-chemnitz.de/ansprechpartner/"),
    mode: LaunchMode.externalApplication,
  );
  return false;
}
