import 'package:flutter/material.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:url_launcher/url_launcher.dart';

class FFJKGTab extends StatefulWidget {
  const FFJKGTab({super.key});

  @override
  State<FFJKGTab> createState() => _FFJKGTabState();
}

class _FFJKGTabState extends State<FFJKGTab> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          const Text(
            "FFJKG - Freunde und Förderer des Johannes-Kepler-Gymnasiums",
            style: TextStyle(fontSize: 16),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ElevatedButton(onPressed: () {
              launchUrl(Uri.parse("mailto:ffjkg@kepler-chemnitz.de"))
                .onError((_, __) {
                  showSnackBar(text: "Fehler beim Öffnen");
                  return false;
                });
            }, child: const Text("Kontaktieren")),
          ),
        ],
      ),
    );
  }
}
