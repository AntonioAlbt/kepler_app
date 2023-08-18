import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/introduction.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/sentry_dsn.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/tasks.dart';
import 'package:kepler_app/loading_screen.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/news/news_data.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

final _newsCache = NewsCache();
final _internalState = InternalState();
final _prefs = Preferences();
final _credStore = CredentialStore();
final _appState = AppState();
final _stuPlanData = StuPlanData();

Future<void> loadAndPrepareApp() async {
  final sprefs = sharedPreferences;
  // TODO? seperate all data files into actual JSON files, not sp keys?
  if (sprefs.containsKey(newsCachePrefKey)) {
    // TODO: save news cache as a JSON in the cache dir of the OS
    _newsCache.loadFromJson(sprefs.getString(newsCachePrefKey)!);
  }
  if (await securePrefs.containsKey(key: credStorePrefKey)) {
    _credStore.loadFromJson((await securePrefs.read(key: credStorePrefKey))!);
  }
  if (sprefs.containsKey(internalStatePrefsKey)) {
    _internalState.loadFromJson(sprefs.getString(internalStatePrefsKey)!);
  }
  if (sprefs.containsKey(stuPlanDataPrefsKey)) {
    // TODO: also save to extra file bc it will get BEEEEG
    _stuPlanData.loadFromJson(sprefs.getString(stuPlanDataPrefsKey)!);
  }

  Workmanager().initialize(
    taskCallbackDispatcher,
    //isInDebugMode: kDebugMode
  );
  Workmanager().registerPeriodicTask(
      (Platform.isIOS) ? Workmanager.iOSBackgroundTask : newsFetchTaskName,
      newsFetchTaskName,
      frequency: const Duration(minutes: 120),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      initialDelay: const Duration(seconds: 5));
  if (_newsCache.newsData.isNotEmpty) {
    loadAllNewNews(_newsCache.newsData.first.link).then((data) {
      if (data != null) _newsCache.insertNewsData(0, data);
    });
  } else {
    final data = await loadNews(0);
    if (data != null) _newsCache.addNewsData(data);
  }

  initializeNotifications();
  await IndiwareDataManager.removeOldCacheFiles();
}

Future<void> prepareApp() async {
  sharedPreferences = await SharedPreferences.getInstance();
  final sprefs = sharedPreferences;
  if (sprefs.containsKey(prefsPrefKey)) _prefs.loadFromJson(sprefs.getString(prefsPrefKey)!);
  await IndiwareDataManager.createDataDirIfNecessary();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appRunner() => prepareApp().then((_) {
    runApp(const MyApp());
  });
  if (kDebugMode || !sentryEnabled) {
    appRunner();
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDSN;
        options.tracesSampleRate = 0.5;
      },
      appRunner: appRunner,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeplerApp();
  }
}

T? cast<T>(x) => x is T ? x : null;

class KeplerApp extends StatefulWidget {
  const KeplerApp({super.key});

  @override
  State<KeplerApp> createState() => _KeplerAppState();
}

final globalScaffoldKey = GlobalKey<ScaffoldState>();
ScaffoldState get globalScaffoldState => globalScaffoldKey.currentState!;

const _loadingAnimationDuration = 1000;

class _KeplerAppState extends State<KeplerApp> {
  UserType utype = UserType.nobody;

  Future<UserType> calcUT() async {
    if (_credStore.lernSaxToken != null) {
      final check = await confirmLernSaxCredentials(_credStore.lernSaxLogin, _credStore.lernSaxToken!);
      if (check == false) {
        _credStore.lernSaxToken = null;
      }
      if (check == null) {
        return _internalState.lastUserType ?? UserType.nobody;
      } else if (_credStore.vpUser == null || _credStore.vpPassword == null) {
        return UserType.nobody;
      } else {
        final ut = await determineUserType(_credStore.lernSaxLogin, _credStore.vpUser, _credStore.vpPassword);
        if (ut == UserType.nobody) {
          _credStore.vpUser = null;
          _credStore.vpPassword = null;
        }
      }
    }
    return _internalState.lastUserType ?? UserType.nobody;
  }

  Future _load() async {
    final t1 = DateTime.now();
    await loadAndPrepareApp();
    utype = await calcUT();
    _internalState.lastUserType = utype;
    // This seems unneccessary and makes the login process a lot more difficult to handle (also adds a lot of requests).
    // _credStore.addListener(() {
    //   calcUT().then((value) {
    //     _appState.setUserType(value);
    //     _internalState.lastUserType = value;
    //   });
    // });

    if (!_internalState.introShown) {
      introductionDisplay = InfoScreenDisplay(
        infoScreens: introScreens,
      );
    }

    final mdif = DateTime.now().difference(t1).inMilliseconds;
    if (kDebugMode) print("Playing difference: $mdif");
    if (mdif < _loadingAnimationDuration) await Future.delayed(Duration(milliseconds: _loadingAnimationDuration - mdif));
    setState(() => _loading = false);
  }

  bool _loading = true;
  InfoScreenDisplay? introductionDisplay;

  @override
  Widget build(BuildContext context) {
    final mainWidget = MultiProvider(
      key: const Key("mainWidget"),
      providers: [
        ChangeNotifierProvider(
          create: (_) => _appState
            ..infoScreen = introductionDisplay // TODO: show "sign in again" screens to user if creds are invalid
            ..userType = utype,
        ),
        ChangeNotifierProvider(
          create: (_) => _prefs,
        ),
        ChangeNotifierProvider(
          create: (_) => _internalState,
        ),
        ChangeNotifierProvider(
          create: (_) => _newsCache,
        ),
        ChangeNotifierProvider(
          create: (_) => _credStore,
        ),
        ChangeNotifierProvider(
          create: (_) => _stuPlanData,
        ),
      ],
      child: Consumer<AppState>(builder: (context, state, __) {
        final index = state.selectedNavPageIDs;
        return WillPopScope(
          onWillPop: () async {
            if (state.infoScreen != null) {
              if (infoScreenState.tryCloseCurrentScreen()) {
                state.clearInfoScreen();
              }
              return false;
            }
            return true;
          },
          child: Stack(
            children: [
              Scaffold(
                key: globalScaffoldKey,
                appBar: AppBar(
                  title: Text((index.first == PageIDs.home)
                      ? "Kepler-App"
                      : cast<Text>(cast<NavEntryData>(destinations.where((element) => element.id == index.last))
                                  ?.label)
                              ?.data ??
                          "Kepler-App"),
                  scrolledUnderElevation: 5,
                  elevation: 5,
                  actions: [
                    IconButton(
                      onPressed: () {
                        state.infoScreen = InfoScreenDisplay(
                          infoScreens: introScreens,
                        );
                      },
                      icon: const Icon(Icons.adb),
                    ),
                  ],
                ),
                drawer: TheDrawer(
                  selectedIndex: index.join("."),
                  onDestinationSelected: (val) {
                    state.selectedNavPageIDs = val.split(".");
                  },
                  entries: destinations,
                  dividers: const [5],
                ),
                body: tabs[index.first],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 100),
                child: state.infoScreen,
              ),
            ],
          ),
        );
      }),
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
                brightness:
                    (_prefs.darkTheme) ? Brightness.dark : Brightness.light),
          ),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: (_loading) ? loadingWidget : mainWidget,
      ),
    );
  }

  @override
  void initState() {
    _load();
    super.initState();
  }

  @override
  void didChangeDependencies() {
    deviceInDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    super.didChangeDependencies();
  }
}
