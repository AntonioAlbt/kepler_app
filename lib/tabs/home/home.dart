import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
                  sendNotification(NotificationContent(id: 124, channelKey: newsNotificationKey, body: "hi, das ist ein Test", notificationLayout: NotificationLayout.BigText));
                  showSnackBar(text: "sent");
                },
                child: const Text("Send news notification"),
              ),
              if (kDebugMode) ElevatedButton(
                onPressed: () {
                  sendNotification(NotificationContent(
                    id: 124, channelKey: stuPlanNotificationKey, body: "hi, das ist ein Test\nzeilenumbrüche\n sind schwer. wie deine mutter hahahhaHAHaHAhahah",
                    notificationLayout: NotificationLayout.BigText,
                    title: "test2 der Kepler App"
                  ));
                  showSnackBar(text: "sent");
                },
                child: const Text("Send stuplan notification"),
              ),
              if (kDebugMode) ElevatedButton(
                onPressed: () {
                  sendNotification(NotificationContent(
                    id: 124, channelKey: stuPlanNotificationKey, body: "hi, das ist ein Test, sach mal der Text hier kann schon ganz schön lang sein das ist ja mal unglaublich wer hat denn sowas authorisiert was soll denn das",
                    notificationLayout: NotificationLayout.Default,
                    title: "Test der kepler app"
                  ));
                  showSnackBar(text: "sent");
                },
                child: const Text("Send sp notif - different type 1"),
              ),
              if (kDebugMode) ElevatedButton(
                onPressed: () {
                  sendNotification(NotificationContent(
                    id: 124, channelKey: stuPlanNotificationKey, body: "Was ist denn hier lso.\nBei dir wurden einfach Stunden geändert",
                    notificationLayout: NotificationLayout.Inbox,
                    title: "Inbox Test der KA",
                  ));
                  showSnackBar(text: "sent");
                },
                child: const Text("Send sp notif - different type 2"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
