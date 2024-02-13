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
