import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';

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

Color _color(List<int> args) => Color.fromARGB(args[0], args[1], args[2], args[3]);

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

  Color? get stuPlanDataAvailableBorderColor => attributes.containsKey("sp_border_col") ? _color((attributes["sp_border_col"]! as String).split(",").map((e) => int.parse(e)).toList()) : null;
  set stuPlanDataAvailableBorderColor(Color? val) => setSaveNotify("sp_border_col", val != null ? [val.alpha, val.red, val.green, val.blue] : null);

  /// if set, used with normal border color for a vertical gradient
  Color? get stuPlanDataAvailableBorderGradientColor => attributes.containsKey("sp_border_gradient_col") ? _color((attributes["sp_border_gradient_col"]! as String).split(",").map((e) => int.parse(e)).toList()) : null;
  set stuPlanDataAvailableBorderGradientColor(Color? val) => setSaveNotify("sp_border_gradient_col", val != null ? [val.alpha, val.red, val.green, val.blue] : null);

  List<String> get hiddenNavIDs => cast<String>(attributes["hidden_nav_ids"])?.split(",") ?? [];
  set hiddenNavIDs(List<String> val) => setSaveNotify("hidden_nav_ids", val);
  void addHiddenNavID(String id) => hiddenNavIDs = hiddenNavIDs..add(id);
  void removeHiddenNavID(String id) => hiddenNavIDs = hiddenNavIDs..remove(id);

  List<String> get homeScreenWidgetList => cast<String>(attributes["hs_widget_list"])?.split(",") ?? [];
  set homeScreenWidgetList(List<String> val) => setSaveNotify("hs_widget_list", val);
  void resetHomeScreenWidgetList() {
    homeScreenWidgetList = flattenedDestinations.map((e) => e.id).toList();
  }

  String get startNavPage => attributes["start_nav_page"] ?? PageIDs.home;
  set startNavPage(String val) => setSaveNotify("start_nav_page", val);

  bool get confettiEnabled => attributes["confetti_enabled"] ?? false;
  set confettiEnabled(bool val) => setSaveNotify("confetti_enabled", val);

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
