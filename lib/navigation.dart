import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/introduction.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/tabs/about.dart';
import 'package:kepler_app/tabs/feedback.dart';
import 'package:kepler_app/tabs/ffjkg.dart';
import 'package:kepler_app/tabs/home/home.dart';
import 'package:kepler_app/tabs/hourtable/hourtable.dart';
import 'package:kepler_app/tabs/hourtable/pages/all_replaces.dart';
import 'package:kepler_app/tabs/hourtable/pages/class_plan.dart';
import 'package:kepler_app/tabs/hourtable/pages/free_rooms.dart';
import 'package:kepler_app/tabs/hourtable/pages/room_plan.dart';
import 'package:kepler_app/tabs/hourtable/pages/teacher_plan.dart';
import 'package:kepler_app/tabs/hourtable/pages/your_plan.dart';
import 'package:kepler_app/tabs/lernsax/lernsax.dart';
import 'package:kepler_app/tabs/lernsax/pages/mails_page.dart';
import 'package:kepler_app/tabs/lernsax/pages/notifs_page.dart';
import 'package:kepler_app/tabs/lernsax/pages/tasks_page.dart';
import 'package:kepler_app/tabs/meals.dart';
import 'package:kepler_app/tabs/news/news.dart';
import 'package:kepler_app/tabs/settings.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// all IDs should be constants
// all IDs should be lowercase letters only, and definitely not include "." (the dot)
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
  static const roomPlans = "roomPlan";
}

class LernSaxPageIDs {
  static const main = "lsmain";
  static const files = "files";
  static const emails = "emails";
  static const chats = "chats";
  static const messageBoard = "messageBoard";
  static const notifications = "notifications";
  static const tasks = "tasks";
  static const openInBrowser = "inbrowser";
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

final destinations = [
  NavEntryData(
    id: PageIDs.home,
    icon: const Icon(Icons.home_outlined),
    label: const Text("Startseite"),
    selectedIcon: const Icon(Icons.home),
    navbarActions: [
      if (kDebugMode) IconButton(
        onPressed: () {
          Provider.of<AppState>(globalScaffoldContext, listen: false).infoScreen = InfoScreenDisplay(
            infoScreens: introScreens,
          );
        },
        icon: const Icon(Icons.adb),
      ),
    ],
  ),
  const NavEntryData(
    id: PageIDs.news,
    icon: Icon(Icons.newspaper_outlined),
    label: Text("Kepler-News"),
    selectedIcon: Icon(Icons.newspaper),
  ),
  // if (kDebugMode) const NavEntryData(
  //   id: "locked_test_teacher",
  //   icon: Icon(Icons.cases),
  //   label: Text("Test: Nur für Lehrer"),
  //   lockedFor: [UserType.nobody, UserType.pupil, UserType.parent]
  // ),
  // if (kDebugMode) const NavEntryData(
  //   id: "locked_test_pupil",
  //   icon: Icon(Icons.account_box),
  //   label: Text("Test: Nur für Schüler"),
  //   lockedFor: [UserType.nobody, UserType.parent, UserType.teacher]
  // ),
  NavEntryData(
    id: StuPlanPageIDs.main,
    icon: const Icon(Icons.school_outlined),
    label: const Text("Vertretungsplan"),
    selectedIcon: const Icon(Icons.school),
    onTryOpen: stuPlanOnTryOpenCallback,
    onTryExpand: stuPlanOnTryOpenCallback,
    lockedFor: [UserType.nobody],
    redirectTo: [StuPlanPageIDs.main, StuPlanPageIDs.yours],
    children: [
      NavEntryData(
        id: StuPlanPageIDs.yours,
        icon: const Icon(Icons.list_alt_outlined),
        label: Selector<Preferences, bool>(
          selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
          builder: (ctx, sie, _) => Selector<AppState, UserType>(
            selector: (ctx, state) => state.userType,
            builder: (context, user, _) => Text("${user != UserType.parent ? (sie ? "Ihr " : "Dein ") : ""}Stundenplan${user == UserType.parent ? " ${sie ? "Ihres" : "Deines"} Kindes" : ""}"),
          ),
        ),
        selectedIcon: const Icon(Icons.list_alt),
        navbarActions: [
          const IconButton(onPressed: yourStuPlanEditAction, icon: Icon(Icons.edit)),
          const IconButton(onPressed: yourStuPlanRefreshAction, icon: Icon(Icons.refresh)),
        ],
        onTryOpen: stuPlanShowInfoDialog,
      ),
      const NavEntryData(
        id: StuPlanPageIDs.teacherPlan,
        icon: Icon(MdiIcons.humanMaleBoard),
        label: Text("Lehrerpläne"),
        selectedIcon: Icon(MdiIcons.humanMaleBoard),
        visibleFor: [UserType.teacher],
        navbarActions: [
          IconButton(onPressed: teacherPlanRefreshAction, icon: Icon(Icons.refresh)),
        ],
        onTryOpen: stuPlanShowInfoDialog,
      ),
      const NavEntryData(
        id: StuPlanPageIDs.classPlans,
        icon: Icon(Icons.groups_outlined),
        label: Text("Klassenpläne"),
        selectedIcon: Icon(Icons.groups),
        navbarActions: [
          IconButton(onPressed: classPlanRefreshAction, icon: Icon(Icons.refresh)),
        ],
        onTryOpen: stuPlanShowInfoDialog,
      ),
      const NavEntryData(
        id: StuPlanPageIDs.all,
        icon: Icon(Icons.list_outlined),
        label: Text("Alle Vertretungen"),
        selectedIcon: Icon(Icons.list),
        navbarActions: [
          IconButton(onPressed: allReplacesRefreshAction, icon: Icon(Icons.refresh)),
        ],
        onTryOpen: stuPlanShowInfoDialog,
      ),
      const NavEntryData(
        id: StuPlanPageIDs.freeRooms,
        icon: Icon(Icons.door_back_door_outlined),
        label: Text("Freie Zimmer"),
        selectedIcon: Icon(Icons.door_back_door),
        navbarActions: [
          IconButton(onPressed: freeRoomRefreshAction, icon: Icon(Icons.refresh)),
        ],
        onTryOpen: stuPlanShowInfoDialog,
      ),
      const NavEntryData(
        id: StuPlanPageIDs.roomPlans,
        icon: Icon(MdiIcons.doorClosed),
        label: Text("Raumpläne"),
        selectedIcon: Icon(MdiIcons.doorOpen),
        navbarActions: [
          IconButton(onPressed: roomPlanRefreshAction, icon: Icon(Icons.refresh)),
        ],
        onTryOpen: stuPlanShowInfoDialog,
      ),
    ],
  ),
  NavEntryData(
    id: LernSaxPageIDs.main,
    icon: const Icon(Icons.laptop_outlined),
    label: const Text("LernSax"),
    selectedIcon: const Icon(Icons.laptop),
    lockedFor: [UserType.nobody],
    children: [
      NavEntryData(
        id: LernSaxPageIDs.openInBrowser,
        icon: const Icon(MdiIcons.web),
        label: const Text("Im Browser öffnen"),
        externalLink: true,
        onTryOpen: (context) async {
          final creds = Provider.of<CredentialStore>(context, listen: false);
          if (creds.lernSaxToken == null || creds.lernSaxLogin == null) return false;
          final (online, url) = await getSingleUseLoginLink(creds.lernSaxLogin!, creds.lernSaxToken!);
          if (!online) {
            showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
          } else if (url == null) {
            showSnackBar(text: "Fehler beim Erstellen des Links.", error: true);
          } else {
            launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
          }
          return false;
        },
      ),
      const NavEntryData(
        id: LernSaxPageIDs.notifications,
        icon: Icon(Icons.notifications_none),
        selectedIcon: Icon(Icons.notifications),
        label: Text("Benachrichtigungen"),
        navbarActions: [
          IconButton(onPressed: lernSaxNotifsRefreshAction, icon: Icon(Icons.refresh)),
        ],
      ),
      const NavEntryData(
        id: LernSaxPageIDs.tasks,
        icon: Icon(Icons.task_alt),
        label: Text("Aufgaben"),
        navbarActions: [
          IconButton(onPressed: lernSaxTasksRefreshAction, icon: Icon(Icons.refresh)),
        ],
      ),
      const NavEntryData(
        id: LernSaxPageIDs.emails,
        icon: Icon(Icons.mail_outlined),
        selectedIcon: Icon(Icons.mail),
        label: Text("E-Mails"),
        navbarActions: [
          IconButton(onPressed: lernSaxMailsRefreshAction, icon: Icon(Icons.refresh)),
        ],
      ),
      const NavEntryData(
        id: LernSaxPageIDs.files,
        icon: Icon(Icons.folder_copy_outlined),
        // selectedIcon: Icon(Icons.folder_copy),
        label: Text("Dateien"),
        externalLink: true,
        onTryOpen: lernSaxOpenInOfficialApp,
      ),
      const NavEntryData(
        id: LernSaxPageIDs.messageBoard,
        icon: Icon(MdiIcons.bulletinBoard),
        // selectedIcon: Icon(MdiIcons.bulletinBoard),
        label: Text("Nachrichten"),
        externalLink: true,
        onTryOpen: lernSaxOpenInOfficialApp,
      ),
      const NavEntryData(
        id: LernSaxPageIDs.chats,
        icon: Icon(Icons.chat_bubble_outline),
        selectedIcon: Icon(Icons.chat_bubble),
        label: Text("Messenger (Chats)"),
        externalLink: true,
        onTryOpen: lernSaxOpenInOfficialApp,
      ),
    ],
  ),
  const NavEntryData(
    id: PageIDs.foodOrder,
    icon: Icon(Icons.restaurant_outlined),
    label: Text("Essensbestellung"),
    selectedIcon: Icon(Icons.restaurant),
    lockedFor: [UserType.nobody],
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
final flattenedDestinations = (){
  recurseAdd(List<NavEntryData> list, NavEntryData toAdd) {
    list.add(toAdd);
    toAdd.children?.forEach((element) => recurseAdd(list, element));
  }
  final list = <NavEntryData>[];
  for (final dest in destinations) {
    recurseAdd(list, dest);
  }
  return list;
}();

NavEntryData currentlySelectedNavEntry(BuildContext context) {
  final id = Provider.of<AppState>(context).selectedNavPageIDs.last;
  return flattenedDestinations.firstWhere((element) => element.id == id);
}
