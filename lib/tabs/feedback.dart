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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/widgets.dart';
import 'package:provider/provider.dart';

class FeedbackTab extends StatefulWidget {
  const FeedbackTab({super.key});

  @override
  State<FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<FeedbackTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Selector<Preferences, bool>(
                selector: (_, prefs) => prefs.preferredPronoun == Pronoun.sie,
                builder: (context, sie, _) => Text(
                  "Ich freue mich immer über Feedback von ${sie ? "Ihnen" : "Dir"}.\nGerne ${sie ? "können Sie" : "kannst Du"} mir auch Wünsche, Fehler oder Fragen zukommen lassen.",
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: OpenLinkButton(
                  label: "App im ${(Platform.isIOS) ? 'App Store' : 'Play Store'} bewerten",
                  link: Platform.isAndroid
                          ? "https://play.google.com/store/apps/details?id=de.kepler-chemnitz.kepler_app"
                          : "https://apps.apple.com/404",
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: OpenLinkButton(
                  label: "Per E-Mail kontaktieren",
                  link: "mailto:a.albert@gamer153.dev",
                  showTrailingIcon: false,
                  infront: Icon(Icons.mail, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
