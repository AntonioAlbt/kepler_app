import 'dart:developer';
import 'dart:io';
// import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
// import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const newsNotificationKey = "news_notification";
const stuPlanNotificationKey = "stu_plan_notification";

const kAndroid13 = 33;
const kIos9 = 9;

Future<bool> requestNotificationPermission() async {
  log("started request");
  final result = await Permission.notification.request();
  log("successfully requested notification perm, status now $result");
  return result == PermissionStatus.granted;
}

Future<bool> checkNotificationPermission() async {
  return await Permission.notification.isGranted;
}

// the _receiveActions function is called from Android/iOS on another isolate,
// so all final vars outside of the function scope will be null without Dart knowing that they will be.
@pragma("vm:entry-point")
Future<void> _receiveActions(ReceivedAction receivedAction) async {
  final sprefs = await SharedPreferences.getInstance();
  lis() async {
    final internalState = InternalState();
    if (sprefs.containsKey(internalStatePrefsKey)) {
      internalState.loadFromJson(sprefs.getString(internalStatePrefsKey)!);
    }
    return internalState;
  }
  if (receivedAction.channelKey == newsNotificationKey) {
    final context = globalScaffoldKey?.currentContext; // if appKey is in another isolate, it might be null -> see analysis_options.yaml for ignoring the error
    if (context == null) {
      log("clicked news notification, but the context was null");
      // TODO: somehow test this and fix it
      await ((await lis())..nowOpenOnStartup = PageIDs.news).save();
      return;
    }
    log("clicked news notification, now setting the nav index to ${PageIDs.news}");
    // dumb flutter, just because it's called context doesn't mean it's used across async gaps
    // ignore: use_build_context_synchronously
    Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [PageIDs.news];
  } else if (receivedAction.channelKey == stuPlanNotificationKey) {
    final context = globalScaffoldKey?.currentContext;
    if (context == null) {
      await ((await lis())..nowOpenOnStartup = StuPlanPageIDs.main).save();
      return;
    }
    // ignore: use_build_context_synchronously
    Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
  }
}

void initializeNotifications() {
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: newsNotificationKey,
        channelName: "Neue Kepler-News",
        channelDescription: "Benachrichtigungen für neue Kepler-News",
      ),
      NotificationChannel(
        channelKey: stuPlanNotificationKey,
        channelName: "Stundenplan-Änderungen",
        channelDescription: "Benachrichtigungen bei neuen Änderungen im Vertretungsplan",
      ),
    ],
    debug: kDebugMode,
  );
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: _receiveActions
  );
}

Future<bool> isAppInForeground() async {
  // the getAppLifeCycle function doesnt exist for ios, so i have to ignore it
  if (Platform.isIOS) return false;
  return await AwesomeNotifications().getAppLifeCycle() == NotificationLifeCycle.Foreground;
}

// TODO: fix android small notification icon
Future<bool> sendNotification(NotificationContent content, [List<NotificationActionButton>? actions]) async {
  // if (await isAppInForeground()) return false;
  return AwesomeNotifications().createNotification(content: content, actionButtons: actions);
}
