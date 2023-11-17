import 'package:flutter/material.dart';
import 'package:kepler_app/libs/snack.dart';
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
                child: const Text("Zum GitHub-Repo"),
              ),
              ElevatedButton(
                onPressed: () {
                  showLicensePage(context: context);
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
            ],
          ),
        ),
      ),
    );
  }
}
