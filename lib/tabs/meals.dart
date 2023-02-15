import 'dart:io';

import 'package:flutter/material.dart';
import 'package:appcheck/appcheck.dart';
import 'package:url_launcher/url_launcher.dart';

class MealOrderingTab extends StatefulWidget {
  const MealOrderingTab({super.key});

  @override
  State<MealOrderingTab> createState() => _MealOrderingTabState();
}

const appleAppId = "1087734660";
const androidAppId = "biz.dls_gmbh.guten.appetit";
String appId() => (Platform.isIOS) ? appleAppId : androidAppId;

class _MealOrderingTabState extends State<MealOrderingTab> {
  Future<bool> hasDLSApp() async {
    try {
      await AppCheck.checkAvailability(appId());
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text("Das direkte Einbinden des Speiseplans ist uns laut DLS nicht erlaubt, deshalb sind hier Links zu der Webseite bzw. der App von DLS:", style: Theme.of(context).textTheme.bodyLarge),
          ),
          ElevatedButton(
            onPressed: () {
              launchUrl(
                Uri.parse("https://www.dls-gmbh.biz/mein-essen/dash"),
                mode: LaunchMode.externalApplication
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Flexible(child: Text("DLS-Webseite öffnen")),
                Flexible(child: Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.open_in_new, size: 16),
                ))
              ],
            ),
          ),
          FutureBuilder(
            builder: (context, snapshot) => ElevatedButton(
              onPressed: () {
                final hasApp = snapshot.data;
                if (hasApp == null) return;
                if (hasApp) {
                  AppCheck.launchApp(appId());
                } else {
                  launchUrl(Uri.parse(
                    (Platform.isIOS) ? "https://apps.apple.com/de/app/id$appleAppId"
                    : "market://details?id=$androidAppId"
                  )).catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Du scheinst keine App zum Herunterladen von Apps installiert zu haben.")));
                    return true;
                  });
                }
              },
              child: Text((snapshot.data == true) ? "\"Guten APPetit!\" öffnen" : "\"Guten APPetit!\" (DLS-App) installieren"),
            ),
            future: hasDLSApp(),
          )
        ]
      ),
    );
  }
}
