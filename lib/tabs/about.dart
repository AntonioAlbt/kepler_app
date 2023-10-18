import 'package:flutter/material.dart';
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
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const Text("Kepler-App, erstellt 2023 von A. Albert"),
            ElevatedButton(
              onPressed: () {
                launchUrl(
                  Uri.parse("https://github.com/Gamer153/kepler_app"),
                  mode: LaunchMode.externalApplication
                );
              },
              child: const Text("Zum GitHub-Repo"),
            ),
            ElevatedButton(
              onPressed: () {
                showLicensePage(context: context);
              },
              child: const Text("Open-Source-Lizenzen anzeigen"),
            ),
          ],
        ),
      ),
    );
  }
}
