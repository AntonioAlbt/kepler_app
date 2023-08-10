import 'package:flutter/material.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/about.dart';
import 'package:kepler_app/tabs/feedback.dart';
import 'package:kepler_app/tabs/ffjkg.dart';
import 'package:kepler_app/tabs/home/home.dart';
import 'package:kepler_app/tabs/hourtable/hourtable.dart';
import 'package:kepler_app/tabs/lernsax.dart';
import 'package:kepler_app/tabs/meals.dart';
import 'package:kepler_app/tabs/news/news.dart';
import 'package:kepler_app/tabs/settings.dart';
import 'package:provider/provider.dart';

// all IDs should be constants
class PageIDs {
  static const home = "home";
  static const news = "news";
  static const foodOrder = "foodOrder";
  static const ffjkg = "ffjkg";
  static const settings = "settings";
  static const feedback = "feedback";
  static const about = "about";
}

class StuPlanPageIDs {
  static const main = "spmain";
  static const yours = "yours";
  static const classPlans = "classPlans";
  static const all = "all";
  static const freeRooms = "freeRooms";
  static const teacherPlan = "teacherPlan";
}

class LernSaxPageIDs {
  static const main = "lsmain";
  static const notifications = "notifications";
  static const tasks = "tasks";
  /* TODO: others */
}

const tabs = {
  PageIDs.home: HomepageTab(),
  PageIDs.news: NewsTab(),
  StuPlanPageIDs.main: HourtableTab(),
  LernSaxPageIDs.main: LernSaxTab(),
  PageIDs.foodOrder: MealOrderingTab(),
  PageIDs.ffjkg: FFJKGTab(),
  PageIDs.settings: SettingsTab(),
  PageIDs.feedback: FeedbackTab(),
  PageIDs.about: AboutTab(),
};

// TODO: disable some when youre UserType.nobody (but allow to click to login!)
// TODO: hide some when usertype doesnt fit, like Lehrerplan

// all ids should be lowercase letters only, and definitely not include "." (the dot)
final destinations = [
  const NavEntryData(
    id: PageIDs.home,
    icon: Icon(Icons.home_outlined),
    label: Text("Startseite"),
    selectedIcon: Icon(Icons.home),
  ),
  const NavEntryData(
    id: PageIDs.news,
    icon: Icon(Icons.newspaper_outlined),
    label: Text("Kepler-News"),
    selectedIcon: Icon(Icons.newspaper),
  ),
  NavEntryData(
    id: StuPlanPageIDs.main,
    icon: const Icon(Icons.school_outlined),
    label: const Text("Vertretungsplan"),
    selectedIcon: const Icon(Icons.school),
    children: [
      NavEntryData(
        id: StuPlanPageIDs.yours,
        icon: const Icon(Icons.list_alt_outlined),
        label: Selector<Preferences, bool>(
          selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
          builder: (ctx, sie, _) => Text("${sie ? "Ihr" : "Dein"} Stundenplan"),
        ),
        selectedIcon: const Icon(Icons.list_alt),
      ),
      const NavEntryData(
        id: StuPlanPageIDs.classPlans,
        icon: Icon(Icons.groups_outlined),
        label: Text("Klassenpläne"),
        selectedIcon: Icon(Icons.groups),
      ),
      const NavEntryData(
        id: StuPlanPageIDs.all,
        icon: Icon(Icons.list_outlined),
        label: Text("Alle Vertretungen"),
        selectedIcon: Icon(Icons.list),
      ),
      const NavEntryData(
        id: StuPlanPageIDs.freeRooms,
        icon: Icon(Icons.door_back_door_outlined),
        label: Text("Freie Zimmer"),
        selectedIcon: Icon(Icons.door_back_door),
      ),
      const NavEntryData(
        id: StuPlanPageIDs.teacherPlan,
        icon: Icon(Icons.groups_outlined),
        label: Text("Lehrerpläne"),
        selectedIcon: Icon(Icons.groups),
        visibleFor: [UserType.teacher],
      ),
    ],
  ),
  const NavEntryData(
    id: LernSaxPageIDs.main,
    icon: Icon(Icons.laptop_outlined),
    label: Text("LernSax"),
    selectedIcon: Icon(Icons.laptop),
  ),
  const NavEntryData(
    id: PageIDs.foodOrder,
    icon: Icon(Icons.restaurant_outlined),
    label: Text("Essensbestellung"),
    selectedIcon: Icon(Icons.restaurant),
  ),
  const NavEntryData(
    id: PageIDs.ffjkg,
    icon: Icon(Icons.diversity_1_outlined),
    label: Text("Förderverein (FFJKG)"),
    selectedIcon: Icon(Icons.diversity_1),
  ),
  const NavEntryData(
    id: PageIDs.settings,
    icon: Icon(Icons.settings_outlined),
    label: Text("Einstellungen"),
    selectedIcon: Icon(Icons.settings),
  ),
  const NavEntryData(
    id: PageIDs.feedback,
    icon: Icon(Icons.message_outlined),
    label: Text("Feedback & Kontakt"),
    selectedIcon: Icon(Icons.message),
  ),
  const NavEntryData(
    id: PageIDs.about,
    icon: Icon(Icons.info_outlined),
    label: Text("Über diese App"),
    selectedIcon: Icon(Icons.info),
  )
];

final parentalData = (){

}();
