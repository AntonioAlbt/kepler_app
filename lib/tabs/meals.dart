import 'dart:io';

import 'package:flutter/material.dart';
import 'package:appcheck/appcheck.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/snack.dart';
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
      await AppCheck.checkAvailability(androidAppId);
      return true;
    } catch (e, s) {
      logCatch("dls-app-avail", e, s);
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
            child: Text("Das direkte Einbinden des Speiseplans ist uns aus rechtlichen Gründen nicht erlaubt, deshalb sind hier Links zu der Webseite bzw. der App von DLS:", style: Theme.of(context).textTheme.bodyLarge),
          ),
          ElevatedButton(
            onPressed: () {
              launchUrl(
                Uri.parse("https://www.dls-gmbh.biz/mein-essen/dash"),
                mode: LaunchMode.externalApplication
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text("DLS-Webseite öffnen")),
                Flexible(child: Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.open_in_new, size: 16),
                ))
              ],
            ),
          ),
          (Platform.isAndroid) ? FutureBuilder( // for iOS, i'd need to check if the url scheme for the dls app exists, but there's no way for me to know the url scheme (if one even exists at all)
            builder: (context, snapshot) => ElevatedButton(
              onPressed: () {
                final hasApp = snapshot.data;
                if (hasApp == null) return;
                if (hasApp) {
                  AppCheck.launchApp(appId());
                } else {
                  launchUrl(Uri.parse("market://details?id=$androidAppId")).catchError((e) {
                    showSnackBar(text: "Keine App zum Installieren von Apps gefunden.", clear: true, error: true);
                    return true;
                  });
                }
              },
              child: Text((snapshot.data == true) ? "\"Guten APPetit!\" öffnen" : "\"Guten APPetit!\" (DLS-App) installieren"),
            ),
            future: hasDLSApp(),
          ) : ElevatedButton(
            onPressed: () => launchUrl(Uri.parse("https://apps.apple.com/de/app/id$appleAppId")),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text("\"Guten APPetit!\" (DLS-App) im App Store")),
                Flexible(child: Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.open_in_new, size: 16),
                ))
              ],
            ),
          ),
        ]
      ),
    );
  }
}
