import 'package:flutter/material.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/tasks.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/tabs/home/widgets/foucault_home.dart';
import 'package:kepler_app/tabs/home/widgets/ls_link_home.dart';
import 'package:kepler_app/tabs/home/widgets/ls_mails_home.dart';
import 'package:kepler_app/tabs/home/widgets/ls_notifs_home.dart';
import 'package:kepler_app/tabs/home/widgets/ls_tasks_home.dart';
import 'package:kepler_app/tabs/home/widgets/news_home.dart';
import 'package:kepler_app/tabs/home/widgets/stuplan_home.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

class HomepageTab extends StatefulWidget {
  const HomepageTab({super.key});

  @override
  State<HomepageTab> createState() => _HomepageTabState();
}

final homeWidgetKeyMap = {
  "news": ("Kepler-News", const HomeNewsWidget(id: "news")),
  "stuplan": ("Aktuelle Vertretungen", const HomeStuPlanWidget(id: "stuplan")),
  "lernsax_browser": ("LernSax öffnen", const HomeLSLinkWidget(id: "lernsax_browser")),
  "lernsax_notifs": ("LernSax: Benachrichtigungen", const HomeLSNotifsWidget(id: "lernsax_notifs")),
  "lernsax_mails": ("LernSax: E-Mails", const HomeLSMailsWidget(id: "lernsax_mails")),
  "lernsax_tasks": ("LernSax: Aufgaben", const HomeLSTasksWidget(id: "lernsax_tasks")),
  "foucault": ("Foucaultsches Pendel", const HomePendulumWidget(id: "foucault")),
};

final widgetsForNotLoggedIn = ["news", "stuplan", "foucault"];

class _HomepageTabState extends State<HomepageTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Consumer<Preferences>(
            builder: (context, prefs, _) {
              return Column(
                children: [
                  ...prefs.homeScreenWidgetOrderList.where((id) => homeWidgetKeyMap.keys.contains(id) && !prefs.hiddenHomeScreenWidgets.contains(id)).map((widget) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: homeWidgetKeyMap[widget]?.$2,
                  )),
                  if (prefs.hiddenHomeScreenWidgets.length == homeWidgetKeyMap.keys.length) const Text("Alle Widgets sind ausgeblendet."),
                  TextButton(
                    onPressed: Provider.of<AppState>(context).userType == UserType.nobody ? null : () => openReorderHomeWidgetDialog(context),
                    child: const Text("Ausgeblendete Widgets verwalten"),
                  ),
                  if (kDebugFeatures) ElevatedButton(
                    onPressed: () {
                      runNewsFetchTask();
                      showSnackBar(text: "sent");
                    },
                    child: const Text("Run news task"),
                  ),
                  if (kDebugFeatures) ElevatedButton(
                    onPressed: () {
                      runStuPlanFetchTask();
                      showSnackBar(text: "sent");
                    },
                    child: const Text("Run stuplan task"),
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final prefs = Provider.of<Preferences>(context, listen: false);
    final istate = Provider.of<InternalState>(context, listen: false);
    final notLoggedIn = Provider.of<AppState>(context, listen: false).userType == UserType.nobody;
    final newIds = homeWidgetKeyMap.keys.where((id) => !istate.widgetsAdded.contains(id) && !prefs.homeScreenWidgetOrderList.contains(id)).where((id) {
      return notLoggedIn ? widgetsForNotLoggedIn.contains(id) : true;
    }).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prefs.homeScreenWidgetOrderList = prefs.homeScreenWidgetOrderList.where((id) {
        return homeWidgetKeyMap.keys.contains(id) && (notLoggedIn ? widgetsForNotLoggedIn.contains(id) : true);
      }).toList() + newIds;
      prefs.homeScreenWidgetOrderList = prefs.homeScreenWidgetOrderList.toSet().toList();
      prefs.hiddenHomeScreenWidgets = prefs.hiddenHomeScreenWidgets.where((e) => e != "").toSet().toList();
      istate.widgetsAdded = newIds;
    });
  }
}

Future<void> openReorderHomeWidgetDialog(BuildContext baseContext) => showDialog(context: baseContext, builder: (context) {
  if (Provider.of<AppState>(context, listen: false).userType == UserType.nobody) {
    return AlertDialog(title: const Text("Fehler"), content: const Text("Anmeldung erforderlich."), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
    ]);
  }
  final prefs = Provider.of<Preferences>(globalScaffoldContext);
  return AnimatedBuilder(
    animation: prefs,
    builder: (context, _) => AlertDialog(
      title: const Text("Reihenfolge"),
      content: SizedBox(
        width: double.maxFinite,
        child: Theme(
          data: Theme.of(context).copyWith(platform: TargetPlatform.windows),
          child: ReorderableListView(
            shrinkWrap: true,
            onReorder: (int oldIndex, int newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final l = prefs.homeScreenWidgetOrderList;
              final old = l.removeAt(oldIndex);
              l.insert(newIndex, old);
              prefs.homeScreenWidgetOrderList = l;
            },
            children: prefs.homeScreenWidgetOrderList.map((id) => Padding(
              key: ValueKey(id),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  IconButton(icon: Icon(prefs.hiddenHomeScreenWidgets.contains(id) ? MdiIcons.eyeOff : MdiIcons.eye, size: 20), onPressed: () {
                    prefs.hiddenHomeScreenWidgets = (prefs.hiddenHomeScreenWidgets.contains(id)) ? (prefs.hiddenHomeScreenWidgets..remove(id)) : (prefs.hiddenHomeScreenWidgets..add(id));
                  }),
                  Flexible(
                    child: Text(
                      homeWidgetKeyMap[id]?.$1 ?? "Unbekannt",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Schließen"),
        ),
      ],
    ),
  );
});
