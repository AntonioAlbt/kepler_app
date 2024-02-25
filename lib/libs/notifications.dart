// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2023-2024 Antonio Albert

// This file is part of kepler_app.

// kepler_app is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// kepler_app is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with kepler_app.  If not, see <http://www.gnu.org/licenses/>.

// Diese Datei ist Teil von kepler_app.

// kepler_app ist Freie Software: Sie können es unter den Bedingungen
// der GNU General Public License, wie von der Free Software Foundation,
// Version 3 der Lizenz oder (nach Ihrer Wahl) jeder neueren
// veröffentlichten Version, weiter verteilen und/oder modifizieren.

// kepler_app wird in der Hoffnung, dass es nützlich sein wird, aber
// OHNE JEDE GEWÄHRLEISTUNG, bereitgestellt; sogar ohne die implizite
// Gewährleistung der MARKTFÄHIGKEIT oder EIGNUNG FÜR EINEN BESTIMMTEN ZWECK.
// Siehe die GNU General Public License für weitere Details.

// Sie sollten eine Kopie der GNU General Public License zusammen mit
// kepler_app erhalten haben. Wenn nicht, siehe <https://www.gnu.org/licenses/>.

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
            Provider.of<AppState>(globalScaffoldContext, listen: false).selectedNavPageIDs = [NewsPageIDs.main, NewsPageIDs.news];
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
