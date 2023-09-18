import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/news/news_data.dart';
import 'package:workmanager/workmanager.dart';

const newsFetchTaskName = "fetch_news";

var lastNotifId = 153;

@pragma('vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void taskCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == newsFetchTaskName || task == Workmanager.iOSBackgroundTask) {
      await runNewsFetchTask();
    }
    return true;
  });
}

Future<void> runNewsFetchTask() async {
  final newsCache = NewsCache();
  if (await fileExists(await newsCacheDataFilePath)) {
    final data = await readFile(await newsCacheDataFilePath);
    if (data != null) newsCache.loadFromJson(data);
  }
  if (!newsCache.loaded || newsCache.newsData.isEmpty) return;
  final canPostNotifications = await checkNotificationPermission();
  if (!canPostNotifications) return;

  final newNews = await loadAllNewNews(newsCache.newsData.first.link, 6);
  if (newNews == null) return;
  // if (kDebugMode) {
  //   newNews.add(
  //     NewsEntryData()
  //       ..createdDate = DateTime.now()
  //       ..link = "https://kepler-chemnitz.de/allgemein/"
  //       ..title = "Vielen Dank an alle, die sich diese App angeschaut haben!"
  //       ..summary = "Es gibt wieder tolles neues Zeug an unserem Gymnasium. Ich habe hier über alles geschrieben, wenn du das aber genau wissen willst, musst du hier klicken."
  //       ..writer = "Einerd Er-Schreiber"
  //   );
  //   newNews.add(
  //     NewsEntryData()
  //       ..createdDate = DateTime.now()
  //       ..link = "https://kepler-chemnitz.de/allgemein/"
  //       ..title = "Landesseminar mit diesem Vlad"
  //       ..summary = "der hat mir auch geholfen - vielen Dank an Vlad von VLANT :D"
  //       ..writer = "Jeman D'Anderes"
  //   );
  // }
  if (newNews.isEmpty) return;

  sendNotification(
    NotificationContent(
      id: lastNotifId,
      channelKey: newsNotificationKey,
      body: "Wir haben neue Kepler-News!<br>${newNews.sublist(0, min(5, newNews.length)).map((e) => "- ${e.title}").join("<br>")}${(newNews.length > 5) ? "\nund weitere..." : ""}",
      category: NotificationCategory.Recommendation,
      notificationLayout: NotificationLayout.BigText
    ),
  );
  lastNotifId++;
}
