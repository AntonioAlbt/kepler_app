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

import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/home/home.dart';

const prefsPrefKey = "user_preferences";

/// Version der Einstellungen, muss für jede Änderung derselben geändert werden,
/// damit die App keine Einstellungen importiert, welche aus einer anderen App-Version stammen
const prefsVersion = 1;

/// globale Variable für aktuelles Gerätefarbschema
bool? deviceInDarkMode;

/// global verfügbar, damit KeplerLogging keinen BuildContext benötigt
bool _loggingEnabled = true;
bool get loggingEnabled => _loggingEnabled;

/// Anredepronomen
enum Pronoun {
  du,
  sie;
  @override
  String toString() => {
    Pronoun.du: "Mit Du anreden",
    Pronoun.sie: "Mit Sie anreden",
  }[this]!;
}

/// Farbschema der App
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

/// Farbe aus Farbwerten erstellen
Color _color(List<int> args) => Color.fromARGB(args[0], args[1], args[2], args[3]);

/// alle Einstellungen, die vom Benutzer angepasst werden können
class Preferences extends SerializableObject with ChangeNotifier {
  final _serializer = Serializer();

  /// Hilfsmethode für alle Klassen mit SerializableObject und ChangeNotifier
  void setSaveNotify(String key, dynamic data) {
    attributes[key] = data;
    notifyListeners();
    save();
  }

  /// Farbschema der App
  AppTheme get theme => AppTheme.values.firstWhere((element) => element.name == (attributes["theme"] ?? ""), orElse: () => AppTheme.system);
  set theme(AppTheme theme) => setSaveNotify("theme", theme.name);
  /// sollte das Dark Theme verwendet werden? (Hilfsvariable, nur lesbar)
  bool get darkTheme => theme == AppTheme.dark || (theme == AppTheme.system && (deviceInDarkMode ?? true));

  /// gewünschte Anrede
  Pronoun get preferredPronoun => Pronoun.values.firstWhere((element) => element.name == (attributes["preferred_pronoun"] ?? ""), orElse: () => Pronoun.du);
  set preferredPronoun(Pronoun pp) => setSaveNotify("preferred_pronoun", pp.name);

  /// soll der Stundenplan unendlich weit in die Zukunft und Vergangenheit blätterbar sein
  bool get enableInfiniteStuPlanScrolling => attributes["enable_is_sp"] ?? false;
  set enableInfiniteStuPlanScrolling(bool val) => setSaveNotify("enable_is_sp", val);

  /// Zeit, ab wann standardmäßig der Stundenplan für den nächsten Tag angezeigt werden soll
  HMTime get timeToDefaultToNextPlanDay => attributes["time_to_next_plan"] ?? HMTime(14, 45);
  set timeToDefaultToNextPlanDay(HMTime val) => setSaveNotify("time_to_next_plan", val);

  /// Farbe der Umrandung für die Stundenplanansicht, falls Daten verfügbar sind
  Color get stuPlanDataAvailableBorderColor => attributes.containsKey("sp_border_col") ? _color((attributes["sp_border_col"]! as String).split(",").map((e) => int.parse(e)).toList()) : keplerColorBlue;
  set stuPlanDataAvailableBorderColor(Color val) => setSaveNotify("sp_border_col", [val.alpha, val.red, val.green, val.blue].map((e) => e.toString()).join(","));

  /// falls hier eine Farbe gewählt ist, wird sie mit der Hauptfarbe für einen Farbverlauf verwendet
  Color? get stuPlanDataAvailableBorderGradientColor => (attributes.containsKey("sp_border_gradient_col") && attributes["sp_border_gradient_col"] != null) ? _color((attributes["sp_border_gradient_col"]! as String).split(",").map((e) => int.parse(e)).toList()) : null;
  set stuPlanDataAvailableBorderGradientColor(Color? val) => setSaveNotify("sp_border_gradient_col", val != null ? [val.alpha, val.red, val.green, val.blue].map((e) => e.toString()).join(",") : null);

  /// Breite der Farbumrandung in der Stundenplanansicht
  double get stuPlanDataAvailableBorderWidth => attributes["sp_border_width"] ?? 3;
  set stuPlanDataAvailableBorderWidth(double val) => setSaveNotify("sp_border_width", val);
  
  /// sollen Klausuren im Stundenplan angezeigt werden
  bool get stuPlanShowExams => attributes["sp_show_exams"] ?? false;
  set stuPlanShowExams(bool val) => setSaveNotify("sp_show_exams", val);

  /// soll im Stundenplan ein Icon für die letzte Verwendung des Raumes an dem ausgewählten Tag angezeigt werden
  bool get stuPlanShowLastRoomUsage => attributes["sp_show_lru"] ?? true;
  set stuPlanShowLastRoomUsage(bool val) => setSaveNotify("sp_show_lru", val);

  /// ungenutzt - eigentlich, damit der Benutzer Einträge in der Navigationsliste ausblenden kann
  List<String> get hiddenNavIDs => cast<String>(attributes["hidden_nav_ids"])?.split(",") ?? [];
  set hiddenNavIDs(List<String> val) => setSaveNotify("hidden_nav_ids", val.join(","));
  void addHiddenNavID(String id) => hiddenNavIDs = hiddenNavIDs..add(id);
  void removeHiddenNavID(String id) => hiddenNavIDs = hiddenNavIDs..remove(id);

  /// Liste der Widgets der Startseite, werden in angegebener Reihenfolge dort angezeigt
  List<String> get homeScreenWidgetOrderList => cast<String>(attributes["hs_widget_list"])?.split("|") ?? [];
  set homeScreenWidgetOrderList(List<String> val) => setSaveNotify("hs_widget_list", val.join("|"));
  void resetHomeScreenWidgetList() {
    homeScreenWidgetOrderList = homeWidgetKeyMap.keys.toList();
  }

  /// ausgeblendete Widgets der Startseite
  List<String> get hiddenHomeScreenWidgets => cast<String>(attributes["hs_hidden_widgets"])?.split("|") ?? [];
  set hiddenHomeScreenWidgets(List<String> val) => setSaveNotify("hs_hidden_widgets", val.join("|"));

  /// Seite, die beim Öffnen der App ausgewählt sein soll
  String get startNavPage => attributes["start_nav_page"] ?? PageIDs.home;
  set startNavPage(String val) {
    setSaveNotify("start_nav_page", val);
    for (final id in startNavPageIDs) {
      removeHiddenNavID(id);
    }
  }
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

  /// Konfetti auf unterstützten Seiten anzeigen
  bool get confettiEnabled => attributes["confetti_enabled"] ?? false;
  set confettiEnabled(bool val) => setSaveNotify("confetti_enabled", val);

  /// Regenbogenmodus aktivieren
  bool get rainbowModeEnabled => attributes["rainbow_enabled"] ?? false;
  set rainbowModeEnabled(bool val) => setSaveNotify("rainbow_enabled", val);

  /// Aprilscherze anwenden bzw. anzeigen
  bool get aprilFoolsEnabled => attributes["aprilfools_enabled"] ?? false;
  set aprilFoolsEnabled(bool val) => setSaveNotify("aprilfools_enabled", val);

  /// IDs aller aktivierten Benachrichtigungen
  List<String> get enabledNotifs => cast<String>(attributes["notif_enabled"])?.split(",") ?? [];
  set enabledNotifs(List<String> val) => setSaveNotify("notif_enabled", val.join(","));
  void addEnabledNotif(String val) {
    if (enabledNotifs.contains(val)) return;
    enabledNotifs = enabledNotifs..add(val);
  }
  void removeEnabledNotif(String val) {
    enabledNotifs = enabledNotifs..remove(val);
  }

  /// soll der Stundenplan einmal täglich neu geladen werden?
  bool get reloadStuPlanAutoOnceDaily => attributes["sp_rl_on_open_d"] ?? true;
  set reloadStuPlanAutoOnceDaily(bool val) => setSaveNotify("sp_rl_on_open_d", val);

  /// sollen Mails in der LernSax-Mail-Liste automatisch beim Vorbeiscrollen heruntergeladen werden?
  bool get lernSaxAutoLoadMailOnScrollBy => attributes["ls_mail_auto_load_osb"] ?? true;
  set lernSaxAutoLoadMailOnScrollBy(bool val) => setSaveNotify("ls_mail_auto_load_osb", val);
  
  /// sollen die Optionen für das Anordnen und Ausblenden der Home-Widgets angezeigt werden?
  bool get showHomeWidgetEditOptions => attributes["show_home_weo"] ?? true;
  set showHomeWidgetEditOptions(bool val) => setSaveNotify("show_home_weo", val);

  /// Anzahl der Tage, die ein Log aufbewart werden soll
  int get logRetentionDays => attributes["log_retention_days"] ?? 90;
  set logRetentionDays(int val) => setSaveNotify("log_retention_days", val);

  /// sollen Debug-Logs gespeichert werden?
  bool get loggingEnabled => attributes["logging_enabled"] ?? true;
  set loggingEnabled(bool val) {
    setSaveNotify("logging_enabled", val);
    _loggingEnabled = val;
  }
  
  /// soll die Möglichkeit zum Hinzufügen von Stundenplänen/Klassen auf der Seite "Dein Stundenplan" angezeigt werden?
  bool get showYourPlanAddDropdown => attributes["show_yp_addrop"] ?? true;
  set showYourPlanAddDropdown(bool val) => setSaveNotify("show_yp_addrop", val);

  /// Host für VLANT-LogUp
  String? get logUpHost => attributes["log_up_url"] ?? kBaseLogUpHost;
  set logUpHost(String? val) => setSaveNotify("log_up_url", val ?? kBaseLogUpHost);

  bool loaded = false;

  Future<void> save() async {
    sharedPreferences.setString(prefsPrefKey, serialize());
  }
  String serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    _serializer.deserialize(json, this);
    loaded = true;
    _loggingEnabled = loggingEnabled;
  }

  Preferences() {
    objectCreators["time_to_next_plan"] = (_) => HMTime(14, 45);
    objectCreators["stuplan_names"] = (_) => <String>[];
  }
}