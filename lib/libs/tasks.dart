import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/news/news_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const fetchTaskName = "fetch_task";

var lastNotifId = 153;

@pragma('vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void taskCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // TODO: fix workmanager for ios
    if (await isAppInForeground()) return false;

    final canPostNotifications = await checkNotificationPermission();
    if (!canPostNotifications) return false;

    final sprefs = await SharedPreferences.getInstance();  
    final prefs = Preferences();
    if (sprefs.containsKey(prefsPrefKey)) {
      prefs.loadFromJson(sprefs.getString(prefsPrefKey)!);
    }

    if (prefs.enabledNotifs.contains(newsNotificationKey)) {
      await runNewsFetchTask();
    }
    if (prefs.enabledNotifs.contains(stuPlanNotificationKey)) {
      await runStuPlanFetchTask();
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

Future<void> runStuPlanFetchTask() async {
  final spdata = StuPlanData();
  if (await fileExists(await stuPlanDataFilePath)) {
    final data = await readFile(await stuPlanDataFilePath);
    if (data != null) spdata.loadFromJson(data);
  }
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final creds = CredentialStore();
  if (await secureStorage.containsKey(key: credStorePrefKey)) {
    creds.loadFromJson((await secureStorage.read(key: credStorePrefKey))!);
  }
  if (!creds.loaded || creds.vpUser == null || creds.vpPassword == null) return;
  // highly complex boolean logic in the next line
  // you might not even be able to comprehend it
  // because i certainly can't
  if (!spdata.loaded || !(spdata.selectedClassName != null || spdata.selectedTeacherName != null)) return;

  // this does look like it'll use quite some of the users data, but for 12 times a day with 5 plans, each one only 12kB it's actually only about 720kB per day, which is fine
  var differentLessons = (spdata.selectedTeacherName != null) ? await getDifferentTeacherLessons(creds, spdata.selectedTeacherName!) : await getDifferentClassLessons(creds, spdata.selectedClassName!);
  differentLessons ??= (spdata.selectedTeacherName != null && spdata.selectedClassName != null) ? await getDifferentClassLessons(creds, spdata.selectedClassName!) : null;
  if (differentLessons == null) return;

  // TODO: show notification
}

Future<Map<DateTime, VPLesson>?> getDifferentClassLessons(CredentialStore creds, String className) async {
  final newDatas = <DateTime, VPKlData>{};
  final oldDatas = <DateTime, VPKlData>{};
  for (var i = 0; i < 5; i++) {
    final date = DateTime.now().add(Duration(days: i));
    final (newData, online) = await getStuPlanDataForDate(creds.vpHost ?? baseUrl, creds.vpUser!, creds.vpPassword!, date);
    if (!online) return null;

    if (newData != null) newDatas[date] = newData;

    final oldData = await IndiwareDataManager.getCachedKlDataForDate(date);
    if (oldData != null) oldDatas[date] = oldData;
  }

  final differentLessons = <DateTime, VPLesson>{};
  for (var mdata in newDatas.entries) {
    final date = mdata.key, data = mdata.value;
    for (var klasse in data.classes) {
      if (klasse.className != className) continue;

      final oldKlasse = oldDatas[date]?.classes.firstWhere((c) => c.className == klasse.className);
      for (var lesson in klasse.lessons) {
        if (lesson.startTime == null || lesson.endTime == null) continue;
        final oldLesson = oldKlasse?.lessons.firstWhere((l) => l.startTime == lesson.startTime && l.endTime == lesson.endTime);
        if (oldLesson == null) {
          if (lesson.roomChanged || lesson.subjectChanged || lesson.teacherChanged) {
            differentLessons[date] = lesson;
          }
        } else {
          if (
            oldLesson.roomCodes.join(",") != lesson.roomCodes.join(",") ||
            oldLesson.subjectCode != lesson.subjectCode ||
            oldLesson.teacherCode != lesson.teacherCode ||
            oldLesson.infoText != lesson.infoText
          ) {
            differentLessons[date] = lesson;
          }
        }
      }
    }
  }
  return differentLessons;
}

Future<Map<DateTime, VPLesson>?> getDifferentTeacherLessons(CredentialStore creds, String teacherCode) async {
  final newDatas = <DateTime, VPLeData>{};
  final oldDatas = <DateTime, VPLeData>{};
  for (var i = 0; i < 5; i++) {
    final date = DateTime.now().add(Duration(days: i));
    final (newData, online) = await getLehPlanDataForDate(creds.vpHost ?? baseUrl, creds.vpUser!, creds.vpPassword!, date);
    if (!online) return null;

    if (newData != null) newDatas[date] = newData;

    final oldData = await IndiwareDataManager.getCachedLeDataForDate(date);
    if (oldData != null) oldDatas[date] = oldData;
  }

  final differentLessons = <DateTime, VPLesson>{};
  for (var mdata in newDatas.entries) {
    final date = mdata.key, data = mdata.value;
    for (var teach in data.teachers) {
      if (teach.teacherCode != teacherCode) continue;

      final oldTeach = oldDatas[date]?.teachers.firstWhere((c) => c.teacherCode == teach.teacherCode);
      for (var lesson in teach.lessons) {
        if (lesson.startTime == null || lesson.endTime == null) continue;
        final oldLesson = oldTeach?.lessons.firstWhere((l) => l.startTime == lesson.startTime && l.endTime == lesson.endTime);
        if (oldLesson == null) {
          if (lesson.roomChanged || lesson.subjectChanged || lesson.teachingClassChanged) {
            differentLessons[date] = lesson;
          }
        } else {
          if (
            oldLesson.roomCodes.join(",") != lesson.roomCodes.join(",") ||
            oldLesson.subjectCode != lesson.subjectCode ||
            oldLesson.teacherCode != lesson.teacherCode ||
            oldLesson.infoText != lesson.infoText
          ) {
            differentLessons[date] = lesson;
          }
        }
      }
    }
  }
  return differentLessons;
}
