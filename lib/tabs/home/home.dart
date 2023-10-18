import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/home/news_home.dart';
import 'package:kepler_app/tabs/home/stuplan_home.dart';
import 'package:provider/provider.dart';

class HomepageTab extends StatefulWidget {
  const HomepageTab({super.key});

  @override
  State<HomepageTab> createState() => _HomepageTabState();
}

class _HomepageTabState extends State<HomepageTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: HomeNewsWidget(),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: HomeStuPlanWidget(),
              ),
              if (kDebugMode) Consumer<AppState>(
                builder: (context, state, _) {
                  return Text("Benutzer-Typ: ${state.userType}");
                }
              ),
              if (kDebugMode) Consumer<CredentialStore>(
                builder: (context, state, _) {
                  return Text("Benutzer-Typ: ${state.attributes} - last ut check: ${Provider.of<InternalState>(context, listen: false).lastUserTypeCheck}");
                }
              ),
              if (kDebugMode) ElevatedButton(
                onPressed: () {
                  Provider.of<InternalState>(context, listen: false).lastStuPlanAutoReload = null;
                  showSnackBar(text: "is now ${Provider.of<InternalState>(context, listen: false).lastStuPlanAutoReload}");
                },
                child: const Text("Forget todays stuplan reload"),
              ),
              if (kDebugMode) ElevatedButton(
                onPressed: () {
                  sendNotification(NotificationContent(id: 124, channelKey: newsNotificationKey, body: "hi, das ist ein Test"));
                  showSnackBar(text: "sent");
                },
                child: const Text("Send notification"),
              ),
              if (kDebugMode) ElevatedButton(
                onPressed: () {
                  Provider.of<CredentialStore>(context, listen: false).vpPassword = "random-junk";
                  showSnackBar(text: "done, password is now \"random-junk\"");
                },
                child: const Text("Invalidify stuplan auth"),
              ),
              if (kDebugMode) ElevatedButton(
                onPressed: () {
                  final creds = Provider.of<CredentialStore>(context, listen: false);
                  unregisterApp(creds.lernSaxLogin ?? "", creds.lernSaxToken ?? "");
                  creds.lernSaxToken = "im gay lol";
                  showSnackBar(text: "done, token is now \"im gay lol\"");
                },
                child: const Text("Invalidify lernsax auth"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
