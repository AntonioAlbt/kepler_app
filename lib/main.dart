import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/tasks.dart';
import 'package:kepler_app/tabs/about.dart';
import 'package:kepler_app/tabs/feedback.dart';
import 'package:kepler_app/tabs/ffjkg.dart';
import 'package:kepler_app/tabs/home/home.dart';
import 'package:kepler_app/tabs/hourtable/hourtable.dart';
import 'package:kepler_app/tabs/lernsax.dart';
import 'package:kepler_app/tabs/meals.dart';
import 'package:kepler_app/tabs/news/news.dart';
import 'package:kepler_app/tabs/news/news_data.dart';
import 'package:kepler_app/tabs/settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

Future<void> loadAndPrepareApp() async {
  final sprefs = sharedPreferences;
  if (sprefs.containsKey(newsCachePrefKey)) newsCache.loadFromJson(sprefs.getString(newsCachePrefKey)!);
  if (await securePrefs.containsKey(key: credStorePrefKey)) credentialStore.loadFromJson((await securePrefs.read(key: credStorePrefKey))!);
  if (sprefs.containsKey(internalStatePrefsKey)) internalState.loadFromJson(sprefs.getString(internalStatePrefsKey)!);

  Workmanager().initialize(
    taskCallbackDispatcher,
    //isInDebugMode: kDebugMode
  );
  Workmanager().registerPeriodicTask(
    (Platform.isIOS) ? Workmanager.iOSBackgroundTask : newsFetchTaskName, newsFetchTaskName,
    frequency: const Duration(minutes: 120),
    existingWorkPolicy: ExistingWorkPolicy.replace,
    initialDelay: const Duration(seconds: 5)
  );
  if (newsCache.newsData.isNotEmpty) {
    loadAllNewNews(newsCache.newsData.first.link).then((data) { if (data != null) newsCache.insertNewsData(0, data); });
  } else {
    final data = await loadNews(0);
    if (data != null) newsCache.addNewsData(data); 
  }

  initializeNotifications();
}

Future<void> prepareApp() async {
  sharedPreferences = await SharedPreferences.getInstance();
  final sprefs = sharedPreferences;
  if (sprefs.containsKey(prefsPrefKey)) prefs.loadFromJson(sprefs.getString(prefsPrefKey)!);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  prepareApp().then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeplerApp();
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
        isVisible: (context) => prefs.role == Role.teacher
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

final appKey = GlobalKey();

class _KeplerAppState extends State<KeplerApp> {
  Future _load() async {
    await loadAndPrepareApp();
    setState(() {
      _loading = false;
    });
  }

  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    final mainWidget = ChangeNotifierProvider(
      key: const Key("mainWidget"),
      create: (context) => AppState(),
      child: Consumer<AppState>(
        builder: (context, state, __) {
          final index = state.selectedNavigationIndex;
          return WillPopScope(
            onWillPop: () async {
              if (state.infoScreen != null) {
                if (infoScreenKey.currentState!.canCloseCurrentScreen()) state.clearInfoScreen();
                return false;
              }
              return true;
            },
            child: Stack(
              children: [
                Scaffold(
                  key: appKey,
                  appBar: AppBar(
                    title: Text((index.first == 0) ? "Kepler-App" : cast<Text>(cast<NavEntryData>(destinations[index.first])?.label)?.data ?? "Kepler-App"),
                    scrolledUnderElevation: 5,
                    elevation: 5,
                  ),
                  drawer: TheDrawer(
                    selectedIndex: index.join("."),
                    onDestinationSelected: (val) {
                      state.setNavIndex(val);
                    },
                    entries: destinations,
                    dividers: const [5],
                  ),
                  body: tabs[index.first],
                ),
                if (state.infoScreen != null) state.infoScreen!
              ],
            ),
          );
        }
      ),
    );
    const loadingWidget = Scaffold(
      key: Key("loadingWidget"),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
    return AnimatedBuilder(
      animation: prefs,
      builder: (context, home) {
        return MaterialApp(
          title: "",
          home: home,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: keplerColorBlue,
              brightness: (prefs.darkTheme) ? Brightness.dark : Brightness.light
            ),
          ),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 100),
        child: (_loading) ? loadingWidget : mainWidget,
      ),
    );
  }

  @override
  void initState() {
    _load();
    super.initState();
  }
}
