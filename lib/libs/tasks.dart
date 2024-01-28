import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/libs/filesystem.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/school/news_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const fetchTaskName = "fetch_task";

@pragma('vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void taskCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (kDebugMode) print("hey yo im workin' here!");

    final canPostNotifications = await checkNotificationPermission();
    if (!canPostNotifications) return true;

    final sprefs = await SharedPreferences.getInstance();  
    final prefs = Preferences();
    if (sprefs.containsKey(prefsPrefKey)) {
      prefs.loadFromJson(sprefs.getString(prefsPrefKey)!);
    }

    if (kDebugMode) print("enabledNotifs: ${prefs.enabledNotifs}");

    if (prefs.enabledNotifs.contains(newsNotificationKey)) {
      try {
        await runNewsFetchTask();
      } catch (e, s) {
        if (kDebugMode) print("$e - $s");
        return false;
      }
    }
    if (prefs.enabledNotifs.contains(stuPlanNotificationKey)) {
      try {
        await runStuPlanFetchTask();
      } catch (e, s) {
        if (kDebugMode) print("$e - $s");
        return false;
      }
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
  if (kDebugNotifData) {
      newNews.add(
          NewsEntryData()
              ..createdDate = DateTime.now()
              ..link = "https://kepler-chemnitz.de/allgemein/"
              ..title = "Vielen Dank an alle, die sich diese App angeschaut haben!"
              ..summary = "Es gibt wieder tolles neues Zeug an unserem Gymnasium. Ich habe hier über alles geschrieben, wenn du das aber genau wissen willst, musst du hier klicken."
              ..writer = "Einerd Er-Schreiber"
      );
      // newNews.add(
      //     NewsEntryData()
      //         ..createdDate = DateTime.now()
      //         ..link = "https://kepler-chemnitz.de/allgemein/"
      //         ..title = "Landesseminar mit diesem Vlad"
      //         ..summary = "der hat mir auch geholfen - vielen Dank an Vlad von VLANT :D"
      //         ..writer = "Jeman D'Anderes"
      // );
  } else {
    if (newNews.isEmpty) return;
    
    newsCache.addNewsData(newNews);
  }

  sendNotification(
    title: "Neue Kepler-News",
    body: "${newNews.sublist(0, min(5, newNews.length)).map((e) => "- ${e.title}").join("\n")}${(newNews.length > 5) ? "\nund weitere..." : ""}",
    notifKey: newsNotificationKey,
  );
}

Future<void> runStuPlanFetchTask() async {
  // TODO - future: inform the user about course ids changing -> if a course they had selected doesn't exist anymore (maybe not as a notif but when app opens)

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
  var differentLessons = (spdata.selectedTeacherName != null) ? await getDifferentTeacherLessons(creds, spdata.selectedTeacherName!) : await getDifferentClassLessons(creds, spdata.selectedClassName!, spdata.selectedCourseIDs);
  differentLessons ??= (spdata.selectedTeacherName != null && spdata.selectedClassName != null) ? await getDifferentClassLessons(creds, spdata.selectedClassName!, spdata.selectedCourseIDs) : null;

  if (kDebugNotifData) {
    differentLessons ??= {
      DateTime.now(): [const VPLesson(
        subjectCode: "DE",
        infoText: "",
        roomChanged: false,
        roomCodes: ["153"],
        schoolHour: 2,
        subjectChanged: false,
        teacherCode: "Alb",
        teacherChanged: false,
        startTime: null, endTime: null, subjectID: null,
      )],
    };
  }

  if (differentLessons == null || differentLessons.isEmpty) return;

  initializeDateFormatting();
  final dateFormat = DateFormat("EE", "de-DE");

  sendNotification(
    title: "Neue Änderungen im Stundenplan",
    body: differentLessons.entries.map((e) => "${dateFormat.format(e.key)}:\n   ${e.value.map((val) => "${val.schoolHour}. Stunde - neu: ${val.subjectCode}${val.teacherCode != "" ? " bei " : ""}${val.teacherCode}${val.roomCodes.isNotEmpty ? " (Raum ${val.roomCodes.join(", ")})" : ""}${val.infoText != "" ? " - Info: ${val.infoText}" : ""}").join("\n   ")}").join("\n"),
    notifKey: stuPlanNotificationKey,
    notifId: 281701530, // this is a "random" number, generated by my brain
    // keeping the notifId the same makes it so the notification only gets updated, not a new one sent all the time
  );
}

Future<Map<DateTime, List<VPLesson>>?> getDifferentClassLessons(CredentialStore creds, String className, List<int> selectedCourseIds) async {
  final newDatas = <DateTime, VPKlData>{};
  final oldDatas = <DateTime, VPKlData>{};
  for (var i = 0; i < 5; i++) {
    final date = DateTime.now().add(Duration(days: i));
    final (newData, online) = await getKlXMLForDate(creds.vpHost ?? baseUrl, creds.vpUser!, creds.vpPassword!, date);
    if (!online) return null;

    if (newData != null) newDatas[date] = xmlToKlData(newData);

    final oldData = await IndiwareDataManager.getCachedKlDataForDate(date);
    if (oldData != null) {
      if (kDebugNotifData) {
        final kl = oldData.classes.firstWhere((e) => e.className == "12");
        final l = kl.lessons.removeAt(0);
        kl.lessons.insert(0, VPLesson(schoolHour: l.schoolHour, startTime: l.startTime, endTime: l.endTime, subjectCode: "Cool", subjectChanged: true, teacherCode: l.teacherCode, teacherChanged: l.teacherChanged, roomCodes: l.roomCodes, roomChanged: l.roomChanged, subjectID: l.subjectID, infoText: l.infoText));
        oldDatas[date] = VPKlData(header: oldData.header, holidays: oldData.holidays, classes: [
          ...oldData.classes.where((element) => element.className != "12"),
          kl,
        ], additionalInfo: oldData.additionalInfo);
      } else {
        oldDatas[date] = oldData;
      }
    }

    if (newData != null) await IndiwareDataManager.setCachedKlDataForDate(date, newData);
  }

  final differentLessons = <DateTime, List<VPLesson>>{};
  for (var mdata in newDatas.entries) {
    final date = mdata.key, data = mdata.value;
    for (var klasse in data.classes) {
      if (klasse.className != className) continue;

      final oldKlasse = oldDatas[date]?.classes.cast<VPClass?>().firstWhere((c) => c!.className == klasse.className, orElse: () => null);
      for (var lesson in klasse.lessons) {
        if (lesson.startTime == null || lesson.endTime == null) continue;
        if (!selectedCourseIds.contains(lesson.subjectID)) continue;
        final multipleInHour = (oldKlasse?.lessons.where((l) => l.schoolHour == lesson.schoolHour).length ?? 0) > 1;
        final oldLesson = oldKlasse?.lessons.cast<VPLesson?>().firstWhere((l) => l!.schoolHour == lesson.schoolHour && (multipleInHour ? l.subjectID == lesson.subjectID : true), orElse: () => null);
        if (oldLesson == null) {
          // if the lesson is new and changed
          if (lesson.roomChanged || lesson.subjectChanged || lesson.teacherChanged || lesson.infoText != "") {
            differentLessons[date] = (differentLessons[date] ?? [])..add(lesson);
          }
        } else {
          if (
            oldLesson.roomCodes.join(",") != lesson.roomCodes.join(",") ||
            oldLesson.subjectCode != lesson.subjectCode ||
            oldLesson.teacherCode != lesson.teacherCode ||
            oldLesson.infoText != lesson.infoText
          ) {
            differentLessons[date] = (differentLessons[date] ?? [])..add(lesson);
          }
        }
      }
    }
  }
  return differentLessons;
}

Future<Map<DateTime, List<VPLesson>>?> getDifferentTeacherLessons(CredentialStore creds, String teacherCode) async {
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

  final differentLessons = <DateTime, List<VPLesson>>{};
  for (var mdata in newDatas.entries) {
    final date = mdata.key, data = mdata.value;
    for (var teach in data.teachers) {
      if (teach.teacherCode != teacherCode) continue;

      final oldTeach = oldDatas[date]?.teachers.firstWhere((c) => c.teacherCode == teach.teacherCode);
      for (var lesson in teach.lessons) {
        if (lesson.startTime == null || lesson.endTime == null) continue;
        final multipleInHour = (oldTeach?.lessons.where((l) => l.schoolHour == lesson.schoolHour).length ?? 0) > 1;
        final oldLesson = oldTeach?.lessons.cast<VPLesson?>().firstWhere((l) => l!.schoolHour == lesson.schoolHour && (multipleInHour ? l.subjectID == lesson.subjectID : true), orElse: () => null);
        if (oldLesson == null) {
          if (lesson.roomChanged || lesson.subjectChanged || lesson.teachingClassChanged) {
            differentLessons[date] = (differentLessons[date] ?? [])..add(lesson);
          }
        } else {
          if (
            oldLesson.roomCodes.join(",") != lesson.roomCodes.join(",") ||
            oldLesson.subjectCode != lesson.subjectCode ||
            oldLesson.teacherCode != lesson.teacherCode ||
            oldLesson.infoText != lesson.infoText
          ) {
            differentLessons[date] = (differentLessons[date] ?? [])..add(lesson);
          }
        }
      }
    }
  }
  return differentLessons;
}
