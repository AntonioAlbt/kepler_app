import 'dart:io';
import 'dart:math';

// import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';

const newsNotificationKey = "news_notification";
const stuPlanNotificationKey = "stu_plan_notification";

const kAndroid13 = 33;
const kIos9 = 9;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<bool> requestNotificationPermission() async {
  var result = false;
  if (Platform.isIOS) {
    result = await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(badge: true) ?? false;
  } else {
    result = await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission() ?? false;
  }
  return result;
}

Future<bool> checkNotificationPermission() async {
  if (Platform.isIOS) {
    return await Permission.notification.isGranted;
  } else {
    return await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.areNotificationsEnabled() ?? true;
  }
}

void initializeNotifications() {
  flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings("transparent_app_icon"),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: false,
        defaultPresentSound: false,
        defaultPresentBadge: true,
      ),
    ),
    onDidReceiveNotificationResponse: (action) async {
      if (action.notificationResponseType != NotificationResponseType.selectedNotification) return;
      switch (action.payload) {
        case newsNotificationKey:
          if (globalScaffoldKey?.currentContext == null) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<AppState>(globalScaffoldContext, listen: false).selectedNavPageIDs = [PageIDs.news];
          });
          break;
        case stuPlanNotificationKey:
          if (globalScaffoldKey?.currentContext == null) return;
          final state = Provider.of<AppState>(globalScaffoldContext, listen: false);
          if (state.userType == UserType.nobody) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            state.selectedNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
          });
          break;
      }
    }
  );
}

NotificationDetails newsNotificationDetails(String bigText) => NotificationDetails(
  android: AndroidNotificationDetails(
    newsNotificationKey,
    "Neue Kepler-News",
    channelDescription: "Benachrichtigungen für neue Kepler-News",
    category: AndroidNotificationCategory.social,
    playSound: false,
    styleInformation: BigTextStyleInformation(bigText),
  ),
  iOS: const DarwinNotificationDetails(
    threadIdentifier: newsNotificationKey,
  ),
);
NotificationDetails stuPlanNotificationDetails(String bigText) => NotificationDetails(
  android: AndroidNotificationDetails(
    stuPlanNotificationKey,
    "Stundenplan-Änderungen",
    channelDescription: "Benachrichtigungen bei neuen Änderungen im Vertretungsplan",
    category: AndroidNotificationCategory.social,
    styleInformation: BigTextStyleInformation(bigText),
  ),
  iOS: const DarwinNotificationDetails(
    threadIdentifier: stuPlanNotificationKey,
  ),
);

Future<void> sendNotification({required String title, required String body, required String notifKey, int? notifId}) async {
  if (notifKey != newsNotificationKey && notifKey != stuPlanNotificationKey) return;
  await flutterLocalNotificationsPlugin.show(
    notifId ?? Random().nextInt(153000),
    title,
    body,
    (notifKey == newsNotificationKey) ? newsNotificationDetails(body) : stuPlanNotificationDetails(body),
    payload: notifKey,
  );
}

Future<NotificationAppLaunchDetails?> getNotifLaunchInfo() async => flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
