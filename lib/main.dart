import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/tasks.dart';
import 'package:kepler_app/tabs/about.dart';
import 'package:kepler_app/tabs/feedback.dart';
import 'package:kepler_app/tabs/ffjkg.dart';
import 'package:kepler_app/tabs/home/home.dart';
import 'package:kepler_app/tabs/hourtable.dart';
import 'package:kepler_app/tabs/lernsax.dart';
import 'package:kepler_app/tabs/meals.dart';
import 'package:kepler_app/tabs/news/news.dart';
import 'package:kepler_app/tabs/news/news_data.dart';
import 'package:kepler_app/tabs/settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

Future<void> prepare() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey(newsCachePrefKey)) newsCache.loadFromJson(prefs.getString(newsCachePrefKey)!);
  if (newsCache.newsData.isEmpty) {
    loadNews(0).then((news) {
      if (news == null) return;
      newsCache.addNewsData(news);
    });
  }
  if (await securePrefs.containsKey(key: credStorePrefKey)) credentialStore.loadFromJson((await securePrefs.read(key: credStorePrefKey))!);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  prepare().then((_) {
    Workmanager().initialize(
      taskCallbackDispatcher,
      isInDebugMode: kDebugMode
    );
    Workmanager().registerPeriodicTask(
      (Platform.isIOS) ? Workmanager.iOSBackgroundTask : newsFetchTaskName, newsFetchTaskName,
      frequency: const Duration(hours: 2),
      existingWorkPolicy: ExistingWorkPolicy.keep
    );
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "",
      home: const KeplerApp(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: keplerColorBlue
        )
      ),
    );
  }
}

T? cast<T>(x) => x is T ? x : null;

final lernSaxIcon = Image.asset("assets/lernsax_icon.png", height: 24, width: 24, color: const Color.fromARGB(255, 162, 162, 162));
final lernSaxIconColorful = Image.asset("assets/lernsax_icon.png", height: 24, width: 24);

const tabs = [
  HomepageTab(),
  NewsTab(),
  HourtableTab(),
  LernSaxTab(),
  MealOrderingTab(),
  FFJKGTab(),
  SettingsTab(),
  FeedbackTab(),
  AboutTab()
];

class KeplerApp extends StatefulWidget {
  const KeplerApp({super.key});

  @override
  State<KeplerApp> createState() => _KeplerAppState();
}

final destinations = [
  const NavEntryData(
    icon: Icon(Icons.home_outlined),
    label: Text("Startseite"),
    selectedIcon: Icon(Icons.home),
  ),
  const NavEntryData(
    icon: Icon(Icons.newspaper_outlined),
    label: Text("Kepler-News"),
    selectedIcon: Icon(Icons.newspaper)
  ),
  NavEntryData(
    icon: const Icon(Icons.school_outlined),
    label: const Text("Vertretungsplan"),
    selectedIcon: const Icon(Icons.school),
    children: [
      const NavEntryData(
        icon: Icon(Icons.list_alt_outlined),
        label: Text("Dein Vertretungsplan"),
        selectedIcon: Icon(Icons.list_alt)
      ),
      const NavEntryData(
        icon: Icon(Icons.groups_outlined),
        label: Text("Klassenplan"),
        selectedIcon: Icon(Icons.groups)
      ),
      const NavEntryData(
        icon: Icon(Icons.list_outlined),
        label: Text("Alle Vertretungen"),
        selectedIcon: Icon(Icons.list)
      ),
      const NavEntryData(
        icon: Icon(Icons.door_back_door_outlined),
        label: Text("Freie Zimmer"),
        selectedIcon: Icon(Icons.door_back_door)
      ),
      NavEntryData(
        icon: const Icon(Icons.groups_outlined),
        label: const Text("Lehrerplan"),
        selectedIcon: const Icon(Icons.groups),
        isVisible: (context) => Provider.of<AppState>(context, listen: false).role == Role.teacher
      ),
    ],
  ),
  NavEntryData(
    icon: lernSaxIcon,
    label: const Text("LernSax"),
    selectedIcon: lernSaxIconColorful,
  ),
  const NavEntryData(
    icon: Icon(Icons.restaurant_outlined),
    label: Text("Essensbestellung"),
    selectedIcon: Icon(Icons.restaurant),
  ),
  const NavEntryData(
    icon: Icon(Icons.diversity_1_outlined),
    label: Text("Förderverein (FFJKG)"),
    selectedIcon: Icon(Icons.diversity_1),
  ),
  const NavEntryData(
    icon: Icon(Icons.settings_outlined),
    label: Text("Einstellungen"),
    selectedIcon: Icon(Icons.settings),
  ),
  const NavEntryData(
    icon: Icon(Icons.message_outlined),
    label: Text("Feedback & Kontakt"),
    selectedIcon: Icon(Icons.message),
  ),
  const NavEntryData(
    icon: Icon(Icons.info_outlined),
    label: Text("Über diese App"),
    selectedIcon: Icon(Icons.info),
  )
];

class _KeplerAppState extends State<KeplerApp> {
  /// String to make sub-selections possible (scheme: <code>lvl1.lvl2.lvl3...</code>)<br>
  /// example values: <code>"1", "4", "2.1", "5.2.3", "3.0"</code>
  // String _index = "0";

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: Consumer<AppState>(
        builder: (context, state, __) {
          final index = state.selectedNavigationIndex;
          return Scaffold(
            appBar: AppBar(
              title: Text((index.first == 0) ? "Kepler-App" : cast<Text>(cast<NavEntryData>(destinations[index.first])?.label)?.data ?? "Kepler-App"),
              scrolledUnderElevation: 5,
              elevation: 5,
            ),
            drawer: Consumer<AppState>(
              builder: (context, state, w) {
                return TheDrawer(
                  selectedIndex: index.join("."),
                  onDestinationSelected: (val) {
                    state.setNavIndex(val);
                  },
                  entries: destinations,
                  dividers: const [5],
                );
              }
            ),
            body: tabs[index.first],
            // drawer: NavigationDrawer(
            //   selectedIndex: _index,
            //   onDestinationSelected: (val) {
            //     setState(() => _index = val);
            //     Navigator.pop(context);
            //   },
            //   children: [
            //     Padding(
            //       padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
            //       child: Column(
            //         children: [
            //           const Icon(Icons.filter_outlined, size: 104),
            //           Text("Kepler-App", style: Theme.of(context).textTheme.titleLarge)
            //         ],
            //       ),
            //     ),
            //     ...destinations
            //   ],
            // ),
            // drawer: Drawer(
            //   child: ListView(
            //     padding: EdgeInsets.zero,
            //     children: [
            //       const DrawerHeader(
            //         decoration: BoxDecoration(
            //           color: Colors.blue,
            //         ),
            //         child: Text('Kepler-App'),
            //       ),
            //       ListTile(
            //         leading: const Icon(Icons.home),
            //         title: const Text("Startseite"),
            //         onTap: () {
            //           _index = 0;
            //           Navigator.pop(context);
            //         },
            //       )
            //     ],
            //   ),
            // ),
          );
        }
      ),
    );
  }
}
