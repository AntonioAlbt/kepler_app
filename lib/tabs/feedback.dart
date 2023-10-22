import 'dart:io';

import 'package:flutter/material.dart';
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
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const Text("Feedback geben?"),
            ElevatedButton(
              onPressed: () {
                launchUrl(Uri.parse("https://github.com/AntonioAlbt/kepler_app"),
                    mode: LaunchMode.externalApplication);
              },
              child: Text("App im ${(Platform.isIOS) ? 'App Store' : 'Play Store'} bewerten"),
            )
          ],
        ),
      ),
    );
  }
}
