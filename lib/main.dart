import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/introduction.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/tasks.dart';
import 'package:kepler_app/loading_screen.dart';
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

final _newsCache = NewsCache();
final _internalState = InternalState();
final _prefs = Preferences();
final _credStore = CredentialStore();

Future<void> loadAndPrepareApp() async {
  final sprefs = sharedPreferences;
  if (sprefs.containsKey(newsCachePrefKey)) _newsCache.loadFromJson(sprefs.getString(newsCachePrefKey)!);
  if (await securePrefs.containsKey(key: credStorePrefKey)) _credStore.loadFromJson((await securePrefs.read(key: credStorePrefKey))!);
  if (sprefs.containsKey(internalStatePrefsKey)) _internalState.loadFromJson(sprefs.getString(internalStatePrefsKey)!);

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
  if (_newsCache.newsData.isNotEmpty) {
    loadAllNewNews(_newsCache.newsData.first.link).then((data) { if (data != null) _newsCache.insertNewsData(0, data); });
  } else {
    final data = await loadNews(0);
    if (data != null) _newsCache.addNewsData(data); 
  }

  initializeNotifications();
}

Future<void> prepareApp() async {
  sharedPreferences = await SharedPreferences.getInstance();
  final sprefs = sharedPreferences;
  if (sprefs.containsKey(prefsPrefKey)) _prefs.loadFromJson(sprefs.getString(prefsPrefKey)!);
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
        isVisible: (context) => _prefs.role == Role.teacher
      ),
    ],
  ),
  const NavEntryData(
    icon: Icon(Icons.laptop_outlined),
    label: Text("LernSax"),
    selectedIcon: Icon(Icons.laptop),
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

final appKey = GlobalKey<ScaffoldState>();

const _loadingAnimationDuration = 1000;
class _KeplerAppState extends State<KeplerApp> {
  Future _load() async {
    final t1 = DateTime.now();
    await loadAndPrepareApp();
    final mdif = DateTime.now().difference(t1).inMilliseconds;
    if (kDebugMode) print("Playing difference: $mdif");
    if (mdif < _loadingAnimationDuration) await Future.delayed(Duration(milliseconds: _loadingAnimationDuration - mdif));
    setState(() => _loading = false);
  }

  bool _loading = true;
  InfoScreenDisplay? introductionDisplay;

  @override
  Widget build(BuildContext context) {
    final mainWidget = ChangeNotifierProvider(
      key: const Key("mainWidget"),
      create: (context) => AppState()..setInfoScreen(introductionDisplay),
      child: ChangeNotifierProvider(
        create: (context) => _prefs,
        child: ChangeNotifierProvider(
          create: (context) => _internalState,
          child: ChangeNotifierProvider(
            create: (context) => _newsCache,
            child: ChangeNotifierProvider(
              create: (context) => _credStore,
              child: Consumer<AppState>(
                builder: (context, state, __) {
                  final index = state.selectedNavigationIndex;
                  return WillPopScope(
                    onWillPop: () async {
                      if (state.infoScreen != null) {
                        if (infoScreenKey.currentState!.tryCloseCurrentScreen()) state.clearInfoScreen();
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
                            actions: [IconButton(onPressed: () {
                              final con = InfoScreenDisplayController();
                              state.setInfoScreen(InfoScreenDisplay(infoScreens: introScreens(con), controller: con,));
                            }, icon: const Icon(Icons.adb))],
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 100),
                          child: state.infoScreen,
                        )
                      ],
                    ),
                  );
                }
              ),
            ),
          ),
        ),
      ),
    );
    const loadingWidget = Scaffold(
      key: Key("loadingWidget"),
      body: Center(
        child: LoadingScreen(),
      ),
    );
    return AnimatedBuilder(
      animation: _prefs,
      builder: (context, home) {
        return MaterialApp(
          title: "",
          home: home,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: keplerColorBlue,
              brightness: (_prefs.darkTheme) ? Brightness.dark : Brightness.light
            ),
          ),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: (_loading) ? loadingWidget : mainWidget,
      ),
    );
  }

  final InfoScreenDisplayController _introController = InfoScreenDisplayController();
  late final InfoScreenDisplay introduction;

  List<InfoScreen> introScreens(InfoScreenDisplayController controller) => [
    InfoScreen(
      infoTitle: const Text("Willkommen in der Kepler-App!"),
      infoText: WelcomeScreenMain(displayController: controller),
      closeable: false,
      infoImage: const Text("🎉", style: TextStyle(fontSize: 48)),
    ),
    InfoScreen(
      infoTitle: const Text("LernSax-Anmeldung"),
      infoText: LernSaxScreenMain(displayController: controller),
      closeable: false,
      infoImage: const Icon(Icons.laptop, size: 48),
    ),
    InfoScreen(
      infoTitle: const Text("Stundenplan-Anmeldung"),
      infoText: Consumer<CredentialStore>(
        builder: (ctx, credStore, _) => Text(
          "login: ${credStore.lernSaxLogin}\n\ntoken: ${credStore.lernSaxToken}",
        ),
      ),
      closeable: true,
      infoImage: const Icon(Icons.list_alt),
    ),
  ];

  @override
  void initState() {
    introduction = InfoScreenDisplay(
      infoScreens: introScreens(_introController),
      controller: _introController,
    );

    _load();
    if (_internalState.introductionStep < introduction.infoScreens.length) {
      _internalState.introductionStep = 0;
      introductionDisplay = introduction;
    }
    super.initState();
  }

  @override
  void didChangeDependencies() {
    deviceInDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    super.didChangeDependencies();
  }
}
