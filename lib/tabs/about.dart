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
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/privacy_policy.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
              Text("Kepler-App, erstellt 2023 von A. Albert", style: Theme.of(context).textTheme.bodyLarge),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FutureBuilder(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, datasn) {
                    if (!datasn.hasData) return const Text("App-Version: unbekannt");
                    return Text("App-Version: ${datasn.data?.version} (${datasn.data?.buildNumber})");
                  }
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    launchUrl(
                      Uri.parse("mailto:a.albert@gamer153.dev"),
                      mode: LaunchMode.externalApplication
                    ).catchError((_) {
                      showSnackBar(text: "Keine Anwendung für E-Mails gefunden.");
                      return false;
                    });
                  },
                  child: const Text("Kontaktieren"),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  launchUrl(
                    Uri.parse("https://github.com/AntonioAlbt/kepler_app"),
                    mode: LaunchMode.externalApplication
                  );
                },
                child: const Text("Zum GitHub-Repo (Quelltext ansehen)"),
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
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Datenschutzerklärung der Kepler-App"),
                      content: const PrivacyPolicy(),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("Schließen"),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text("Datenschutzerklärung anzeigen"),
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
            ],
          ),
        ),
      ),
    );
  }
}
