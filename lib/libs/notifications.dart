import 'dart:developer';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:notification_permissions/notification_permissions.dart';
import 'package:provider/provider.dart';

const newsNotificationKey = "news_notification";

const kAndroid13 = 33;
const kIos9 = 9;

Future<bool> requestNotificationPermission() async {
  final result = await NotificationPermissions.requestNotificationPermissions();
  return result == PermissionStatus.granted;
}

Future<bool> checkNotificationPermission() async {
  if (Platform.isAndroid) {
    final aInfo = await DeviceInfoPlugin().androidInfo;
    if (aInfo.version.sdkInt < kAndroid13) return true;
  } else if (Platform.isIOS) {
    final iInfo = await DeviceInfoPlugin().iosInfo;
    if ((int.tryParse(iInfo.systemVersion?.split(".").first ?? "10") ?? 10) < kIos9) return true;
  }
  return await NotificationPermissions.getNotificationPermissionStatus() == PermissionStatus.granted;
}

@pragma("vm:entry-point")
Future<void> _receiveActions(ReceivedAction receivedAction) async {
  if (receivedAction.channelKey == newsNotificationKey) {
    final context = appKey?.currentContext; // if appKey is in another thread, it might be null -> see analysis_options.yaml for ignoring the error
    if (context == null) {
      log("clicked news notification, but the context was null");
      return;
    }
    log("clicked news notification, now setting the nav index to 1");
    Provider.of<AppState>(context, listen: false).setNavIndex("1");
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
    ],
    debug: kDebugMode,
  );
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: _receiveActions
  );
}

Future<bool> sendNotification(NotificationContent content, [List<NotificationActionButton>? actions]) {
  return AwesomeNotifications().createNotification(content: content, actionButtons: actions);
}
