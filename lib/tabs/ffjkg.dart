import 'package:flutter/material.dart';
import 'package:kepler_app/libs/widgets.dart';

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
          ),
          OpenLinkButton(
            label: "Ansprechpartner der Schule",
            link: "https://www.kepler-chemnitz.de/ansprechpartner/",
          ),
        ],
      ),
    );
  }
}
