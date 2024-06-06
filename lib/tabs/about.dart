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
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const keplerAppDSELink = "https://www.kepler-chemnitz.de/materialis/datenschutzerklaerung-kepler-app/";

class AboutTab extends StatefulWidget {
  const AboutTab({super.key});

  @override
  State<AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<AboutTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Die Kepler-App", style: Theme.of(context).textTheme.bodyLarge),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FutureBuilder(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, datasn) {
                    if (!datasn.hasData) return const Text("App-Version: unbekannt");
                    return Text(
                      "erstellt 2023/24 von A. Albert\nApp-Version: ${datasn.data?.version} (${datasn.data?.buildNumber})",
                      textAlign: TextAlign.center,
                    );
                  }
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    launchUrl(
                      Uri.parse("mailto:a.albert@gamer153.dev"),
                      mode: LaunchMode.externalApplication,
                    ).catchError((_) {
                      showSnackBar(text: "Keine Anwendung für E-Mails gefunden.");
                      return false;
                    });
                  },
                  child: const Text("Kontaktieren"),
                ),
              ),
              const OpenLinkButton(
                label: "Zum GitHub-Repo (Quelltext ansehen)",
                link: "https://github.com/AntonioAlbt/kepler_app",
              ),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Diese App ist unter der GPLv3 lizensiert. Der Quelltext ist somit frei verfügbar und Änderungen sind erlaubt, solange der veränderte Quelltext bereitgestellt wird.",
                  style: TextStyle(
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  PackageInfo.fromPlatform().then((data) => showLicensePage(
                        context: context,
                        applicationName: data.appName,
                        applicationVersion: data.version,
                        // applicationIcon: Image.asset("assets/JKGLogo.png", width: 200),
                        applicationLegalese: "Diese App ist unter der GPLv3 lizensiert. Für den Lizenztext siehe den Eintrag kepler_app."
                      ));
                },
                child: const Text("Open-Source-Lizenzen anzeigen"),
              ),
              const OpenLinkButton(
                label: "Datenschutzerklärung anzeigen",
                link: keplerAppDSELink,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    launchUrl(Uri.parse("https://vlant.de"), mode: LaunchMode.externalApplication);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Image.asset("assets/logo${hasDarkTheme(context) ? "_light" : ""}.png", scale: 4),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Divider(indent: 32, endIndent: 32),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: logViewerPageBuilder));
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(flex: 0, child: Text("Debug-Aufzeichnungen ansehen")),
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.bug_report, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (kDebugFeatures) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: () {
                    Provider.of<InternalState>(context, listen: false).lastChangelogShown = 0;
                    showSnackBar(text: "Zurückgesetzt.");
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(flex: 0, child: Text("Changelog-Version zurücksetzen")),
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.timer, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
