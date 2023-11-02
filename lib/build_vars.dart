import 'package:flutter/foundation.dart';

const kIsBetaVersion = bool.fromEnvironment("beta", defaultValue: kDebugMode);
const kDebugFeatures = bool.fromEnvironment("debug_features", defaultValue: kDebugMode);
const kSentryEnabled = bool.fromEnvironment("sentry_enabled", defaultValue: false);
const kDebugNotifData = bool.fromEnvironment("debug_notif_data", defaultValue: false);
