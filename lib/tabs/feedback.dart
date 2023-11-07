import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
                  "Ich freue mich immer über Feedback von ${sie ? "Ihnen" : "Dir"}. Gerne ${sie ? "können Sie" : "kannst Du"} mir auch Wünsche, Fehler oder Fragen zukommen lassen.",
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    launchUrl(
                      Uri.parse(
                        Platform.isAndroid
                            ? "https://play.google.com/store/apps/details?id=dev.gamer153.kepler_app"
                            : "https://apps.apple.com/404",
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Text("App im ${(Platform.isIOS) ? 'App Store' : 'Play Store'} bewerten"),
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
                  child: const Text("Per E-Mail kontaktieren"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
