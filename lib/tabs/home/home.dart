import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/tabs/home/news_home.dart';
import 'package:kepler_app/tabs/home/stuplan_home.dart';

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
              if (kDebugMode) ElevatedButton(
                onPressed: () {
                  sendNotification(title: "News Notify", body: "- Antonio ist der beste\n- #pride", notifKey: newsNotificationKey);
                  showSnackBar(text: "sent");
                },
                child: const Text("Send news notification"),
              ),
              if (kDebugMode) ElevatedButton(
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
          ),
        ),
      ),
    );
  }
}
