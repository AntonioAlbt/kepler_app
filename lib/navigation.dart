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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/introduction.dart';
import 'package:kepler_app/libs/kepler_app_custom_icons.dart';
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
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
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
import 'package:kepler_app/tabs/pendel.dart';
import 'package:kepler_app/tabs/school/calendar.dart';
import 'package:kepler_app/tabs/school/news.dart';
import 'package:kepler_app/tabs/school/school.dart';
import 'package:kepler_app/tabs/settings.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

// all IDs should be constants
// all IDs should be lowercase letters only, and definitely not include "." (the dot)
/// Jede Seite hat ihre eigene ID, und damit keine Strings händig verglichen werden müssen
/// bekommt alles einen Eintrag in der entsprechenden Klasse

/// Haupteinträge (ohne Unterseiten)
class PageIDs {
  static const home = "home";
  static const foodOrder = "foodOrder";
  static const pendel = "pendel";
  static const ffjkg = "ffjkg";
  static const settings = "settings";
  static const feedback = "feedback";
  static const about = "about";
}

/// Stundenplan-Einträge
/// (main ist immer der Eintrag für den obersten Eintrag, der sich ausklappen lässt)
class StuPlanPageIDs {
  static const main = "spmain";
  static const yours = "yours";
  static const classPlans = "classPlans";
  static const all = "all";
  static const freeRooms = "freeRooms";
  static const teacherPlan = "teacherPlan";
  static const roomPlans = "roomPlan";
  static const debug = "debug";
}

/// LernSax-Einträge
class LernSaxPageIDs {
  static const main = "lsmain";
  static const files = "files";
  static const emails = "emails";
  static const chats = "chats";
  static const messageBoard = "messageBoard";
  static const notifications = "notifications";
  static const tasks = "tasks";
  static const openInBrowser = "inbrowser";
  static const add = "lernsax_add";
}

/// Einträge für News bzw. Kalender
class NewsPageIDs {
  static const main = "nwmain";
  static const news = "news";
  static const calendar = "calendar";
}

/// Einträge für FFJKG-Seiten (nur für Eltern angezeigt)
class FFJKGPageIDs {
  static const main = "ffjkgmain";
  static const ffjkg = "ffjkg";
  static const representatives = "reprslnk";
}

/// nur die Haupt-IDs werden einem Tab zugeordnet, um das Anzeigen der ausgewählten Unterseite muss sich jeder Tab
/// selbst kümmern
final tabs = {
  PageIDs.home: const HomepageTab(),
  NewsPageIDs.main: const SchoolTab(),
  StuPlanPageIDs.main: const HourtableTab(),
  LernSaxPageIDs.main: const LernSaxTab(),
  PageIDs.foodOrder: const MealOrderingTab(),
  PageIDs.pendel: PendelInfoTab(),
  FFJKGPageIDs.main: const FFJKGTab(),
  PageIDs.settings: const SettingsTab(),
  PageIDs.feedback: const FeedbackTab(),
  PageIDs.about: const AboutTab(),
};

/// wichtigstes Array - alle Navigationseinträge (und inzwischen auch Zeug zu mehreren Accounts) finden sich hier
/// (die Bedeutung der Einträge ist ziemlich selbsterklärend, siehe immer auch das Label)
/// Einträge können verschiedene Icons für (a) nicht ausgewählt und (b) ausgewählt haben
/// -> (a) ist typischerweise die outlined Variante eines Icons, (b) dann das normale Icon
/// navbarActions werden als kleine Icons mit Funktion in der NavBar oben rechts angezeigt
final destinations = [
  NavEntryData(
    id: PageIDs.home,
    icon: const Icon(Icons.home_outlined),
    label: const Text("Startseite"),
    selectedIcon: const Icon(Icons.home),
    navbarActions: [
      /// für Tests: Intro nochmal anzeigen
      if (kDebugFeatures) IconButton(
        onPressed: () {
          final state = Provider.of<AppState>(globalScaffoldContext, listen: false);
          state.selectedNavPageIDs = ["intro-non-existent"];
          state.navPagesToOpenAfterNextISClose = [PageIDs.home];
          state.infoScreen = InfoScreenDisplay(
            infoScreens: introScreens,
          );
        },
        icon: const Icon(Icons.adb),
      ),
    ],
    ignoreHiding: true,
  ),
  NavEntryData(
    id: NewsPageIDs.main,
    icon: Icon(MdiIcons.newspaperVariantMultipleOutline),
    label: const Text("Neuigkeiten"),
    selectedIcon: Icon(MdiIcons.newspaperVariantMultiple),
    /// beim Auswählen dieser Seite wird der Benutzer auf die News-Seite umgeleitet
    /// da die NewsPage main keinen Inhalt hat
    redirectTo: [NewsPageIDs.main, NewsPageIDs.news],
    children: [
      const NavEntryData(
        id: NewsPageIDs.news,
        icon: Icon(Icons.newspaper_outlined),
        selectedIcon: Icon(Icons.newspaper),
        label: Text("Kepler-News"),
        navbarActions: [
          /// viele Seiten mit Daten haben eine ähnliche Aktion, um die Daten händisch neu laden/aktualisieren zu können
          IconButton(onPressed: newsTabRefreshAction, icon: Icon(Icons.refresh)),
        ],
      ),
      const NavEntryData(
        id: NewsPageIDs.calendar,
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month),
        label: Text("Kepler-Kalender"),
        navbarActions: [
          IconButton(onPressed: calendarTabRefreshAction, icon: Icon(Icons.refresh)),
        ],
      ),
    ],
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
    /// der Stundenplan muss vor dem Öffnen erst eingerichtet werden (siehe stuPlanOnTryOpenCallback)
    /// daher wird, wenn die Einrichtung noch passieren muss, jeder Versuch vom Öffnen oder Ausklappen verhindert,
    /// und der entsprechende InfoScreen angezeigt
    onTryOpen: stuPlanOnTryOpenCallback,
    onTryExpand: stuPlanOnTryOpenCallback,
    /// Einträge können für gewisse Benutzertypen gesperrt sein (Schloss wird angezeigt und entsprechender Dialog
    /// beim Antippen) - für den Stundenplan muss der Benutzer angemeldet sein, deshalb sind alle Einträge dafür
    /// für nicht angemeldete Benutzer gesperrt
    lockedFor: [UserType.nobody],
    /// auch hier hat StuPlanPage main keinen Inhalt -> Umleitung
    redirectTo: [StuPlanPageIDs.main, StuPlanPageIDs.yours],
    children: [
      NavEntryData(
        id: StuPlanPageIDs.yours,
        icon: const Icon(Icons.list_alt_outlined),
        /// Label ist hier so komplex, da sowohl beachtet werden muss:
        /// - ob der Benutzer mit Du oder Sie angesprochen werden will, als auch
        /// - ob der Benutzer ein Elternteil ist, als auch
        /// - ob der Benutzer mehrere Stundenpläne hat
        label: Selector<Preferences, bool>(
          selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
          builder: (ctx, sie, _) => Selector<AppState, UserType>(
            selector: (ctx, state) => state.userType,
            builder: (context, user, _) => Selector<StuPlanData, List<String>>(
              selector: (ctx, stdata) => stdata.altSelectedClassNames,
              builder: (context, data, _) {
                final multiple = data.isNotEmpty;
                final possesive = "${sie ? "Ihr" : "Dein"}${multiple ? "e" : ""}";
                final noun = multiple ? "Stundenpläne" : "Stundenplan";
                if (user == UserType.parent) {
                  return Text("$noun ${sie ? "Ihre" : "Deine"}${multiple ? "r" : "s"} Kinde${multiple ? "r" : "s"}");
                } else {
                  return Text("$possesive $noun");
                }
              },
            ),
          ),
        ),
        selectedIcon: const Icon(Icons.list_alt),
        navbarActions: [
          /// falls Unendlich scrollen aktiviert ist, kann man mit dieser Action zum heutigen Tag zurückspringen
          Consumer<Preferences>(
            builder: (context, prefs, _) {
              if (!prefs.enableInfiniteStuPlanScrolling) return const SizedBox.shrink();
              return const IconButton(onPressed: yourStuPlanJumpToStartAction, icon: Icon(Icons.calendar_today));
            },
          ),
          const IconButton(onPressed: yourStuPlanEditAction, icon: Icon(Icons.edit)),
          const IconButton(onPressed: yourStuPlanRefreshAction, icon: Icon(Icons.refresh)),
        ],
        onTryOpen: stuPlanShowInfoDialog,
      ),
      NavEntryData(
        id: StuPlanPageIDs.teacherPlan,
        icon: Icon(MdiIcons.humanMaleBoard),
        label: const Text("Lehrerpläne"),
        selectedIcon: Icon(MdiIcons.humanMaleBoard),
        /// der Eintrag für Lehrerpläne wird nur Lehrern angezeigt
        visibleFor: [UserType.teacher],
        navbarActions: [
          const IconButton(onPressed: teacherPlanRefreshAction, icon: Icon(Icons.refresh)),
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
      NavEntryData(
        id: StuPlanPageIDs.roomPlans,
        icon: Icon(MdiIcons.doorClosed),
        label: const Text("Raumpläne"),
        selectedIcon: Icon(MdiIcons.doorOpen),
        navbarActions: [
          const IconButton(onPressed: roomPlanRefreshAction, icon: Icon(Icons.refresh)),
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
    /// wieder nur für angemeldete Benutzer
    lockedFor: [UserType.nobody],
    /// da die main-Seite sowohl keinen Inhalt hat, als auch nicht auf einen festen Eintrag umgeleitet
    /// werden kann (wegen mehreren Benutzern, siehe childrenBuilder), ist der Eintrag nicht anwählbar und wird
    /// beim antippen nur ausgeklappt
    selectable: false,
    /// da mehrere Benutzer hinzugefügt werden können, werden die Navigations-Einträge hier dynamisch generiert
    childrenBuilder: (context) {
      /// da der Eintrag sich pro Benutzer unterscheiden muss, weil keine tatsächliche Seite dahinter steht, und
      /// somit der Navigations-Index nicht geändert wird (weshalb die Funktion nie den Benutzer daraus bestimmen
      /// könnte), wird der Eintrag mit dieser Funktion entsprechend erstellt
      NavEntryData lernSaxOpenInBrowserEntry(String login, String token) => NavEntryData(
        id: LernSaxPageIDs.openInBrowser,
        icon: Icon(MdiIcons.web),
        label: const Text("Im Browser öffnen"),
        externalLink: true,
        onTryOpen: (context) => lernSaxOpenInBrowser(context, login, token),
      );

      /// Liste aller Einträge die für jeden Benutzer gleich hinzugefügt werden
      /// die Seiten dieser Einträge bestimmen den aktuell ausgewählten Benutzer aus dem Navigations-Index
      final list = [
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
      ];

      /// diese Einträge müssen nicht für jeden Benutzer hinzugefügt werden, da sie sowieso nur auf die App verweisen
      final openInAppList = [
        const NavEntryData(
          id: LernSaxPageIDs.files,
          icon: Icon(Icons.folder_copy_outlined),
          // selectedIcon: Icon(Icons.folder_copy),
          label: Text("Dateien"),
          externalLink: true,
          onTryOpen: lernSaxOpenInOfficialApp,
        ),
        NavEntryData(
          id: LernSaxPageIDs.messageBoard,
          icon: Icon(MdiIcons.bulletinBoard),
          // selectedIcon: Icon(MdiIcons.bulletinBoard),
          label: const Text("Nachrichten"),
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
      ];
 
      /// da der "Hinzufügen"-Eintrag nur einmalig benötigt wird, ist er hier separat und nicht in einer der Listen
      /// (auch, da seine Position sich ändern kann)
      final addEntry = NavEntryData(
        id: LernSaxPageIDs.add,
        icon: const Icon(Icons.add),
        label: const Text("LernSax-Konto hinzufügen"),
        onTryOpen: (ctx) async {
          final creds = Provider.of<CredentialStore>(globalScaffoldContext, listen: false);
          if (creds.lernSaxLogin == lernSaxDemoModeMail) {
            await showDialog(
              context: ctx,
              builder: (ctx) => AlertDialog(
                title: Text("Nicht verfügbar"),
                content: Text("Im Demo-Modus können keine LernSax-Konten hinzugefügt werden."),
              ),
            );
            return false;
          }
          await showDialog(
            context: ctx,
            builder: (ctx) => AlertDialog(
              title: const Text("LernSax-Konto hinzufügen"),
              content: LernSaxScreenMain(
                onRegistered: (mail, token, context) {
                  final creds = Provider.of<CredentialStore>(globalScaffoldContext, listen: false);
                  creds.addAlternativeLSUser(mail, token);
                  Navigator.pop(context);
                  showSnackBar(text: "LernSax-Konto erfolgreich hinzugefügt.");
                  globalScaffoldState.closeDrawer();
                },
                onNonLogin: (_) {},
                allowNotLogin: false,
                again: true,
                extraPadding: false,
                additionalAccount: true,
              ),
            ),
          );
          return false;
        },
      );

      /// ähnlich wie der lernSaxOpenInBrowserEntry, wird der Eintrag zum Entfernen eines Benutzers für jeden
      /// Benutzer separat und dynamisch benötigt und wird hier generiert
      removeEntry(int uid, String login) => NavEntryData(
        /// die ID ist eigentlich egal, da der Eintrag nicht ausgewählt werden kann (onTryOpen gibt immer false zurück)
        id: "ls_remove$uid",
        icon: const Icon(Icons.remove),
        label: const Text("Abmelden"),
        onTryOpen: (ctx) async {
          final remove = await showDialog(
            context: ctx,
            builder: (ctx) => AlertDialog(
              title: const Text("Abmelden"),
              content: Text("Wirklich Konto $login in der App abmelden?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text("Abbrechen"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text("Ja, abmelden"),
                ),
              ],
            ),
          );
          if (!globalScaffoldContext.mounted) return false;
          if (remove == true) {
            final creds = Provider.of<CredentialStore>(globalScaffoldContext, listen: false);
            final (login, token) = (creds.alternativeLSLogins[uid - 1], creds.alternativeLSTokens[uid - 1]);
            try {
              // nicht awaiten, damit es einfach im Hintergrund passiert
              // oder fehlschlägt (ist auch egal)
              unregisterApp(login, token);
            } on Exception catch (_) {}
            creds.removeAlternativeLSUser(uid - 1);
            globalScaffoldState.closeDrawer();
          }
          return false;
        },
      );

      final creds = Provider.of<CredentialStore>(context, listen: false);
      /// sollte eigentlich nicht passieren, da der Eintrag für nicht angemeldete Benutzer gesperrt ist -
      /// aber better safe than sorry
      if (creds.lernSaxLogin == null || creds.lernSaxToken == null) {
        return [
          const NavEntryData(id: "ls_no", icon: Icon(Icons.abc), label: Text("Nicht angemeldet.")),
        ];
      }

      final loginList = [creds.lernSaxLogin!, ...creds.alternativeLSLogins];
      /// nur wenn mehrere Benutzer angemeldet sind, werden die Einträgt doppelt verschachtelt, bei nur 1 Benutzer
      /// sieht die Übersicht unverändert aus
      if (loginList.length > 1) {
        return loginList.asMap().entries.map((entry) =>
          NavEntryData(
            /// der Login des Benutzers wird in der ID des NavEntrys und damit im Navigations-Index "verschlüsselt"
            /// platziert (base64Url statt base64 da ich mir nicht sicher war ob base64 vielleicht den "." enthält
            /// und ich zu faul war, nachzulesen - base64Url geht auf jeden Fall)
            id: "lslogin:${base64UrlEncode(utf8.encode(entry.value))}",
            icon: const Icon(Icons.person_outline),
            label: Text(entry.value + (entry.key == 0 ? " (primär)" : "")),
            /// removeEntry wird beim Hauptbenutzer (index = 0) nicht hinzugefügt
            children: [lernSaxOpenInBrowserEntry(entry.value, entry.key == 0 ? creds.lernSaxToken! : creds.alternativeLSTokens[entry.key - 1]), ...list, if (entry.key > 0) removeEntry(entry.key, entry.value)],
            selectedIcon: const Icon(Icons.person),
            /// nur aufklappbar
            selectable: false,
          )
        ).toList()..addAll(openInAppList)..add(addEntry);
      } else {
        return [lernSaxOpenInBrowserEntry(creds.lernSaxLogin!, creds.lernSaxToken!), ...list, ...openInAppList, addEntry];
      }
    }
  ),
  const NavEntryData(
    id: PageIDs.foodOrder,
    icon: Icon(Icons.restaurant_outlined),
    label: Text("Essensbestellung"),
    selectedIcon: Icon(Icons.restaurant),
    lockedFor: [UserType.nobody],
  ),
  const NavEntryData(
    id: PageIDs.pendel,
    icon: Icon(KeplerAppCustomIcons.pendulumIcon),
    label: Text("Foucaultsches Pendel"),
    navbarActions: [
      IconButton(onPressed: pendelInfoRefreshAction, icon: Icon(Icons.refresh)),
    ],
  ),
  const NavEntryData(
    id: FFJKGPageIDs.main,
    icon: Icon(Icons.diversity_1_outlined),
    label: Text("Förderverein (FFJKG)"),
    selectedIcon: Icon(Icons.diversity_1),
    visibleFor: [UserType.nobody, UserType.pupil, UserType.teacher],
  ),
  /// auf Wunsch von Frau Korndörfer sieht der Eintrag für Eltern anders aus und verweist direkt auch auf die
  /// Ansprechpartner der Schule (statt nur auf der Seite FFJKGPageIDs.main oder FFJKGPageIDs.ffjkg)
  const NavEntryData(
    visibleFor: [UserType.parent],
    id: FFJKGPageIDs.main,
    icon: Icon(Icons.diversity_1_outlined),
    label: Text("Ansprechpartner & Förderverein", style: TextStyle(fontSize: 14)),
    selectedIcon: Icon(Icons.diversity_1),
    children: [
      NavEntryData(
        id: FFJKGPageIDs.representatives,
        icon: Icon(Icons.person_pin),
        label: Text("Ansprechpartner der Schule"),
        externalLink: true,
        onTryOpen: ffjkgSchoolReprOpen,
      ),
      NavEntryData(
        id: FFJKGPageIDs.ffjkg,
        icon: Icon(Icons.diversity_3),
        label: Text("Förderverein (FFJKG)"),
      ),
    ],
  ),
  const NavEntryData(
    id: PageIDs.settings,
    icon: Icon(Icons.settings_outlined),
    label: Text("Einstellungen"),
    selectedIcon: Icon(Icons.settings),
    ignoreHiding: true,
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
  ),
];

/// da die Kinder-Einträge mit childrenBuilder dynamisch generiert werden, kann das Ergebnis der Rekursion
/// nicht in einer anderen Liste/Map zwischengespeichert werden
/// mainly used to determine the title and navbar actions needed to display for the current page
NavEntryData? currentlySelectedNavEntry(BuildContext context) {
  final id = Provider.of<AppState>(context, listen: false).selectedNavPageIDs.join(".");
  NavEntryData? search(NavEntryData entry, String idBase) {
    // print("searching for $id in ${entry.id} -> $idBase${entry.id}");
    if (id == "$idBase${entry.id}") {
      return entry;
    }
    for (final child in entry.getChildren(context)) {
      final result = search(child, "$idBase${entry.id}.");
      if (result != null) {
        return result;
      }
    }
    return null;
  }
  for (final entry in destinations) {
    final result = search(entry, "");
    if (result != null) {
      return result;
    }
  }
  return null;
}
