import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/home/home.dart';

const prefsPrefKey = "user_preferences";

bool? deviceInDarkMode;

bool _loggingEnabled = true;
bool get loggingEnabled => _loggingEnabled;

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

  bool get enableInfiniteStuPlanScrolling => attributes["enable_is_sp"] ?? false;
  set enableInfiniteStuPlanScrolling(bool val) => setSaveNotify("enable_is_sp", val);

  HMTime get timeToDefaultToNextPlanDay => attributes["time_to_next_plan"] ?? HMTime(14, 45);
  set timeToDefaultToNextPlanDay(HMTime val) => setSaveNotify("time_to_next_plan", val);

  Color get stuPlanDataAvailableBorderColor => attributes.containsKey("sp_border_col") ? _color((attributes["sp_border_col"]! as String).split(",").map((e) => int.parse(e)).toList()) : keplerColorBlue;
  set stuPlanDataAvailableBorderColor(Color val) => setSaveNotify("sp_border_col", [val.alpha, val.red, val.green, val.blue].map((e) => e.toString()).join(","));

  /// if set, used with normal border color for a vertical gradient
  Color? get stuPlanDataAvailableBorderGradientColor => (attributes.containsKey("sp_border_gradient_col") && attributes["sp_border_gradient_col"] != null) ? _color((attributes["sp_border_gradient_col"]! as String).split(",").map((e) => int.parse(e)).toList()) : null;
  set stuPlanDataAvailableBorderGradientColor(Color? val) => setSaveNotify("sp_border_gradient_col", val != null ? [val.alpha, val.red, val.green, val.blue].map((e) => e.toString()).join(",") : null);

  double get stuPlanDataAvailableBorderWidth => attributes["sp_border_width"] ?? 3;
  set stuPlanDataAvailableBorderWidth(double val) => setSaveNotify("sp_border_width", val);

  List<String> get hiddenNavIDs => cast<String>(attributes["hidden_nav_ids"])?.split(",") ?? [];
  set hiddenNavIDs(List<String> val) => setSaveNotify("hidden_nav_ids", val);
  void addHiddenNavID(String id) => hiddenNavIDs = hiddenNavIDs..add(id);
  void removeHiddenNavID(String id) => hiddenNavIDs = hiddenNavIDs..remove(id);

  List<String> get homeScreenWidgetOrderList => cast<String>(attributes["hs_widget_list"])?.split("|") ?? [];
  set homeScreenWidgetOrderList(List<String> val) => setSaveNotify("hs_widget_list", val.join("|"));
  void resetHomeScreenWidgetList() {
    homeScreenWidgetOrderList = homeWidgetKeyMap.keys.toList();
  }

  List<String> get hiddenHomeScreenWidgets => cast<String>(attributes["hs_hidden_widgets"])?.split("|") ?? [];
  set hiddenHomeScreenWidgets(List<String> val) => setSaveNotify("hs_hidden_widgets", val.join("|"));

  String get startNavPage => attributes["start_nav_page"] ?? PageIDs.home;
  set startNavPage(String val) => setSaveNotify("start_nav_page", val);
  List<String> get startNavPageIDs {
    switch (startNavPage) {
      case StuPlanPageIDs.all:
      case StuPlanPageIDs.yours:
        return [StuPlanPageIDs.main, startNavPage];
        
      case LernSaxPageIDs.notifications:
      case LernSaxPageIDs.emails:
        return [LernSaxPageIDs.main, startNavPage];

      case NewsPageIDs.news:
      case NewsPageIDs.calendar:
        return [NewsPageIDs.main, startNavPage];
      
      // app versions older than 1.3.3 (25) used to set this for "your stuplan"
      case StuPlanPageIDs.main:
        startNavPage = StuPlanPageIDs.yours;
        return [StuPlanPageIDs.main, StuPlanPageIDs.yours];

      default:
        return [startNavPage];
    }
  }

  bool get confettiEnabled => attributes["confetti_enabled"] ?? false;
  set confettiEnabled(bool val) => setSaveNotify("confetti_enabled", val);

  List<String> get enabledNotifs => cast<String>(attributes["notif_enabled"])?.split(",") ?? [];
  set enabledNotifs(List<String> val) => setSaveNotify("notif_enabled", val.join(","));
  void addEnabledNotif(String val) {
    if (enabledNotifs.contains(val)) return;
    enabledNotifs = enabledNotifs..add(val);
  }
  void removeEnabledNotif(String val) {
    enabledNotifs = enabledNotifs..remove(val);
  }

  bool get reloadStuPlanAutoOnceDaily => attributes["sp_rl_on_open_d"] ?? true;
  set reloadStuPlanAutoOnceDaily(bool val) => setSaveNotify("sp_rl_on_open_d", val);

  bool get lernSaxAutoLoadMailOnScrollBy => attributes["ls_mail_auto_load_osb"] ?? true;
  set lernSaxAutoLoadMailOnScrollBy(bool val) => setSaveNotify("ls_mail_auto_load_osb", val);
  
  bool get showHomeWidgetEditOptions => attributes["show_home_weo"] ?? true;
  set showHomeWidgetEditOptions(bool val) => setSaveNotify("show_home_weo", val);

  int get logRetentionDays => attributes["log_retention_days"] ?? 90;
  set logRetentionDays(int val) => setSaveNotify("log_retention_days", val);

  bool get loggingEnabled => attributes["logging_enabled"] ?? true;
  set loggingEnabled(bool val) {
    setSaveNotify("logging_enabled", val);
    _loggingEnabled = val;
  }

  bool loaded = false;

  Future<void> save() async {
    sharedPreferences.setString(prefsPrefKey, _serialize());
  }
  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    _serializer.deserialize(json, this);
    loaded = true;
    _loggingEnabled = loggingEnabled;
  }

  Preferences() {
    objectCreators["time_to_next_plan"] = (_) => HMTime(14, 45);
  }
}
