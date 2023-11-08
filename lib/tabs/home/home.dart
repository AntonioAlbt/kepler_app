import 'package:flutter/material.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/tabs/home/foucault_home.dart';
import 'package:kepler_app/tabs/home/ls_link_home.dart';
import 'package:kepler_app/tabs/home/ls_mails_home.dart';
import 'package:kepler_app/tabs/home/ls_notifs_home.dart';
import 'package:kepler_app/tabs/home/ls_tasks_home.dart';
import 'package:kepler_app/tabs/home/news_home.dart';
import 'package:kepler_app/tabs/home/stuplan_home.dart';
import 'package:provider/provider.dart';

class HomepageTab extends StatefulWidget {
  const HomepageTab({super.key});

  @override
  State<HomepageTab> createState() => _HomepageTabState();
}

final homeWidgetKeyMap = {
  "news": const HomeNewsWidget(),
  "stuplan": const HomeStuPlanWidget(),
  "lernsax_browser": const HomeLSLinkWidget(),
  "lernsax_notifs": const HomeLSNotifsWidget(),
  "lernsax_mails": const HomeLSMailsWidget(),
  "lernsax_tasks": const HomeLSTasksWidget(),
  "foucault": const HomePendulumWidget(),
};

class _HomepageTabState extends State<HomepageTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Consumer<Preferences>(
            builder: (context, prefs, _) {
              return Column(
                children: [
                  ...homeWidgetKeyMap.values.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: w,
                  )),
                  if (kDebugFeatures) ElevatedButton(
                    onPressed: () {
                      sendNotification(title: "News Notify", body: "- Antonio ist der beste\n- #pride", notifKey: newsNotificationKey);
                      showSnackBar(text: "sent");
                    },
                    child: const Text("Send news notification"),
                  ),
                  if (kDebugFeatures) ElevatedButton(
                    onPressed: () {
                      sendNotification(
                        title: "Test StuPlan Notif",
                        body: "Hallo, das ist ein Test.\n\nWir versuchen, Sie wegen\nverlängerter Garantie für Ihr Auto\nzu kontaktieren.",
                        notifKey: stuPlanNotificationKey,
                      );
                      showSnackBar(text: "sent");
                    },
                    child: const Text("Send stuplan notification"),
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }
}
