import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/state.dart';

const prefsPrefKey = "user_preferences";

bool? deviceInDarkMode;

enum Pronoun {
  du,
  sie;
  @override
  String toString() => {
    Pronoun.du: "Mit Du anreden",
    Pronoun.sie: "Mit Sie anreden",
  }[this]!;
}
enum AppTheme {
  system,
  dark,
  light;
  @override
  String toString() => {
    AppTheme.system: "System",
    AppTheme.dark: "Dunkel",
    AppTheme.light: "Hell",
  }[this]!;
}

class Preferences extends SerializableObject with ChangeNotifier {
  final _serializer = Serializer();

  void setSaveNotify(String key, dynamic data) {
    attributes[key] = data;
    notifyListeners();
    save();
  }

  AppTheme get theme => AppTheme.values.firstWhere((element) => element.name == (attributes["theme"] ?? ""), orElse: () => AppTheme.system);
  set theme(AppTheme theme) => setSaveNotify("theme", theme.name);
  bool get darkTheme => theme == AppTheme.dark || (theme == AppTheme.system && (deviceInDarkMode ?? true));

  Pronoun get preferredPronoun => Pronoun.values.firstWhere((element) => element.name == (attributes["preferred_pronoun"] ?? ""), orElse: () => Pronoun.du);
  set preferredPronoun(Pronoun pp) => setSaveNotify("preferred_pronoun", pp.name);

  bool get considerLernSaxTasksAsCancellation => attributes["consider_ls_tasks_as_cl"] ?? true;
  set considerLernSaxTasksAsCancellation(bool val) => setSaveNotify("consider_ls_tasks_as_cl", val);
  
  bool get showLernSaxCancelledLessonsInRoomPlan => attributes["show_ls_cl_irp"] ?? true;
  set showLernSaxCancelledLessonsInRoomPlan(bool val) => setSaveNotify("show_ls_cl_irp", val);

  HMTime get timeToDefaultToNextPlanDay => attributes["time_to_next_plan"] ?? HMTime(16, 00);
  set timeToDefaultToNextPlanDay(HMTime val) => setSaveNotify("time_to_next_plan", val);

  bool loaded = false;

  save() async {
    sharedPreferences.setString(prefsPrefKey, _serialize());
  }
  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    _serializer.deserialize(json, this);
    loaded = true;
  }

  Preferences() {
    objectCreators["time_to_next_plan"] = (_) => HMTime(16, 0);
  }
}
