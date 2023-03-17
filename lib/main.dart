import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/about.dart';
import 'package:kepler_app/tabs/feedback.dart';
import 'package:kepler_app/tabs/ffjkg.dart';
import 'package:kepler_app/tabs/home.dart';
import 'package:kepler_app/tabs/hourtable.dart';
import 'package:kepler_app/tabs/lernsax.dart';
import 'package:kepler_app/tabs/meals.dart';
import 'package:kepler_app/tabs/news.dart';
import 'package:kepler_app/tabs/settings.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:developer' as dev;

@pragma('vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    if (task == newsFetchTaskName) {
      dev.log("fetching news...");
    }
    return Future.value(true);
  });
}

const newsFetchTaskName = "fetch_news";

void main() {
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode
  );
  Workmanager().registerPeriodicTask(
    newsFetchTaskName, newsFetchTaskName,
    frequency: const Duration(hours: 2),
    backoffPolicy: BackoffPolicy.linear
  );
  runApp(const MyApp());
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
  const NavEntryData(
    icon: Icon(Icons.school_outlined),
    label: Text("Vertretungsplan"),
    selectedIcon: Icon(Icons.school),
    children: [
      NavEntryData(
        icon: Icon(Icons.list_alt_outlined),
        label: Text("Dein Vertretungsplan"),
        selectedIcon: Icon(Icons.list_alt)
      ),
      NavEntryData(
        icon: Icon(Icons.groups_outlined),
        label: Text("Klassenplan"),
        selectedIcon: Icon(Icons.groups)
      ),
      NavEntryData(
        icon: Icon(Icons.list_outlined),
        label: Text("Alle Vertretungen"),
        selectedIcon: Icon(Icons.list)
      ),
      NavEntryData(
        icon: Icon(Icons.door_back_door_outlined),
        label: Text("Freie Zimmer"),
        selectedIcon: Icon(Icons.door_back_door)
      )
    ]
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
  String _index = "0";

  List<int> indices() => _index.split(".").map((e) => int.parse(e)).toList();

  @override
  Widget build(BuildContext context) {
    final mainIndex = indices().first;
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: Scaffold(
        appBar: AppBar(
          title: Text((_index == "0") ? "Kepler-App" : cast<Text>(cast<NavEntryData>(destinations[mainIndex])?.label)?.data ?? "Kepler-App"),
          scrolledUnderElevation: 5,
          elevation: 5,
        ),
        drawer: Consumer<AppState>(
          builder: (context, state, w) {
            return TheDrawer(
              selectedIndex: _index,
              onDestinationSelected: (val) {
                setState(() => _index = val);
                state.setNavIndex(val);
              },
              entries: destinations,
              dividers: const [5],
            );
          }
        ),
        body: tabs[mainIndex],
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
      ),
    );
  }
}
