import 'dart:io';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/introduction.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/sentry_dsn.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/tasks.dart';
import 'package:kepler_app/libs/filesystem.dart' as fs;
import 'package:kepler_app/loading_screen.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
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
final _lernSaxData = LernSaxData();

final ConfettiController globalConfettiController = ConfettiController();

Future<void> loadAndPrepareApp() async {
  final sprefs = sharedPreferences;
  if (await fs.fileExists(await newsCacheDataFilePath)) {
    final data = await fs.readFile(await newsCacheDataFilePath);
    if (data != null) _newsCache.loadFromJson(data);
  }
  if (await securePrefs.containsKey(key: credStorePrefKey)) {
    _credStore.loadFromJson((await securePrefs.read(key: credStorePrefKey))!);
  }
  if (sprefs.containsKey(internalStatePrefsKey)) {
    _internalState.loadFromJson(sprefs.getString(internalStatePrefsKey)!);
  }
  if (await fs.fileExists(await stuPlanDataFilePath)) {
    final data = await fs.readFile(await stuPlanDataFilePath);
    if (data != null) _stuPlanData.loadFromJson(data);
  }
  if (await fs.fileExists(await lernSaxDataFilePath)) {
    final data = await fs.readFile(await lernSaxDataFilePath);
    if (data != null) _lernSaxData.loadFromJson(data);
  }

  Workmanager().initialize(
    taskCallbackDispatcher,
    // isInDebugMode: kDebugMode
  );
  // this is only applicable to android, because for iOS I'm using the background fetch capability - it's interval is configured in the swift app delegate
  if (Platform.isAndroid) {
    try {
      // add this because users on previous versions of the app with the old "fetch_news" task will have both running
      Workmanager().cancelByUniqueName("fetch_news");
    } on Exception catch (_) {}
    Workmanager().registerPeriodicTask(
      fetchTaskName,
      fetchTaskName,
      frequency: const Duration(minutes: 120),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      initialDelay: const Duration(seconds: 5),
    );
  }
  
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

void showLoginScreenAgain({ bool clearData = true }) {
  final ctx = globalScaffoldContext;
  if (clearData) {
    Provider.of<CredentialStore>(ctx, listen: false).clearData();
    Provider.of<InternalState>(ctx, listen: false).introShown = false;
  }
  Provider.of<AppState>(ctx, listen: false)
    ..selectedNavPageIDs = [PageIDs.home] // isn't neccessarily the default screen (because of prefs), but idc
    ..infoScreen = InfoScreenDisplay(
      infoScreens: loginAgainScreens,
    );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS || Platform.isAndroid) {
      return const KeplerApp();
    } else {
      return const Center(
        child: Text("Gerät nicht unterstüzt."),
      );
    }
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
BuildContext get globalScaffoldContext => globalScaffoldKey.currentContext!;

// const _loadingAnimationDuration = 1000;

/// returns: null = request error, usertype.(pupil|teacher) = success, usertype.nobody = invalid creds
Future<UserType?> checkIndiwareData(String host, String username, String password) async {
  try {
    final lres = await authRequest(lUrlMLeXmlUrl(host), username, password);
    // if null, throw -> to catch block
    if (lres!.statusCode == 401) { // if teacher auth failed, try again with pupil auth
      final sres = await authRequest(sUrlMKlXmlUrl(host), username, password);
      if (sres!.statusCode == 401) return UserType.nobody;
      if (sres.statusCode != 200) return null;
      return UserType.pupil;
    }
    if (lres.statusCode != 200) return null;
    return UserType.teacher;
  } catch (_) {
    return null;
  }
}

class _KeplerAppState extends State<KeplerApp> {
  UserType utype = UserType.nobody;
  bool isStuplanInvalid = false;
  bool isLernsaxInvalid = false;

  Future<UserType> calcUT() async {
    if (
      _internalState.lastUserType != null &&
      _internalState.lastUserType != UserType.nobody &&
      (_internalState.lastUserTypeCheck?.difference(DateTime.now()).abs().inHours ?? 0) < 23
    ) {
      return _internalState.lastUserType!;
    }
    _internalState.lastUserTypeCheck = DateTime.now();
    if (_credStore.lernSaxToken != null && _credStore.lernSaxLogin != null) {
      final (online, check) = await confirmLernSaxCredentials(_credStore.lernSaxLogin!, _credStore.lernSaxToken!);
      if (!online) {
        showSnackBar(textGen: (sie) => "LernSax ist nicht erreichbar. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden? Die App kann nicht auf aktuelle Daten zugreifen.");
        return _internalState.lastUserType ?? UserType.nobody;
      }
      if (check == false) {
        isLernsaxInvalid = true;
        _credStore.lernSaxLogin = null;
        _credStore.lernSaxToken = null;
      }
      if (
        _credStore.vpPassword == null ||
        _credStore.vpUser == null ||
        await () async {
          final ut = await checkIndiwareData(_credStore.vpHost ?? baseUrl, _credStore.vpUser ?? "u", _credStore.vpPassword ?? "p");
          return ut == UserType.nobody || (_internalState.lastUserType == UserType.teacher && ut == UserType.pupil);
        }()
      ) {
        isStuplanInvalid = true;
        _credStore.vpHost = null;
        _credStore.vpUser = null;
        _credStore.vpPassword = null;
      }
      if (isLernsaxInvalid || isStuplanInvalid) return UserType.nobody;
      if (check == null) {
        // no internet = assume user didn't change
        showSnackBar(textGen: (sie) => "LernSax ist nicht erreichbar. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden? Die App kann nicht auf aktuelle Daten zugreifen.");
        return _internalState.lastUserType ?? UserType.nobody;
      } else {
        final ut = await determineUserType(_credStore.lernSaxLogin!, _credStore.lernSaxToken!);
        return ut;
      }
    }
    return UserType.nobody;
  }

  Future<void> _load() async {
    final t1 = DateTime.now();
    await loadAndPrepareApp();
    utype = await calcUT();
    _internalState.lastUserType = utype;

    if (!_internalState.introShown) {
      introductionDisplay = InfoScreenDisplay(
        infoScreens: introScreens,
      );
    } else {
      if (isLernsaxInvalid || isStuplanInvalid) {
        final both = isLernsaxInvalid && isStuplanInvalid;
        showSnackBar(textGen: (sie) => "${sie ? "Ihre" : "Deine"} Anmeldedaten für ${isLernsaxInvalid ? "LernSax" : ""}${both ? " und " : ""}${isStuplanInvalid ? "den Stundenplan" : ""} sind ungültig. Bitte ${sie ? "melden Sie sich" : "melde Dich"} erneut an.");
        introductionDisplay = InfoScreenDisplay(
          infoScreens: [
            if (isLernsaxInvalid) lernSaxLoginAgainScreen(false),
            if (isStuplanInvalid) stuPlanLoginAgainScreen,
            finishScreen,
          ],
        );
      }
      if (!await checkNotificationPermission()) {
        await requestNotificationPermission();
      }
    }

    final mdif = DateTime.now().difference(t1).inMilliseconds;
    if (kDebugMode) print("Playing difference: $mdif");
    // if (mdif < _loadingAnimationDuration) await Future.delayed(Duration(milliseconds: _loadingAnimationDuration - mdif));
    // await Future.delayed(const Duration(seconds: 100));

    final launchInfo = await getNotifLaunchInfo();
    if (launchInfo != null && launchInfo.didNotificationLaunchApp && launchInfo.notificationResponse != null && launchInfo.notificationResponse!.payload != null) {
      switch (launchInfo.notificationResponse!.payload!) {
        case newsNotificationKey:
          startingNavPageIDs = [PageIDs.news];
          break;
        case stuPlanNotificationKey:
          startingNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
          break;
      }
    }

    setState(() => _loading = false);
  }

  bool _loading = true;
  InfoScreenDisplay? introductionDisplay;

  List<String>? startingNavPageIDs;

  @override
  Widget build(BuildContext context) {
    final mainWidget = MultiProvider(
      key: const Key("mainWidget"),
      providers: [
        ChangeNotifierProvider(
          create: (_) => _appState
            ..infoScreen = introductionDisplay
            ..userType = utype
            ..selectedNavPageIDs = (){
              if (startingNavPageIDs != null) return startingNavPageIDs!;
              return _prefs.startNavPageIDs;
            }(),
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
        ChangeNotifierProvider(
          create: (_) => _lernSaxData,
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
              WillPopScope(
                onWillPop: () async {
                  if (_appState.selectedNavPageIDs != _prefs.startNavPageIDs) {
                    _appState.selectedNavPageIDs = _prefs.startNavPageIDs;
                    return false;
                  } else {
                    return true;
                  }
                },
                child: Scaffold(
                  key: globalScaffoldKey,
                  appBar: AppBar(
                    title: (index.first == PageIDs.home) ? const Text("Kepler-App")
                      : currentlySelectedNavEntry(context).label,
                    scrolledUnderElevation: 5,
                    elevation: 5,
                    // this is so the two appbars in that page seem like theyre one
                    shadowColor: ([StuPlanPageIDs.classPlans, StuPlanPageIDs.teacherPlan, StuPlanPageIDs.roomPlans, LernSaxPageIDs.tasks].contains(state.selectedNavPageIDs.last)) ? const Color(0x0529323b) : null,
                    actions: currentlySelectedNavEntry(context).navbarActions,
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
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: globalConfettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  blastDirection: pi * 0.5,
                  colors: const [
                    Colors.red,
                    Colors.orange,
                    Colors.yellow,
                    Colors.green,
                    Colors.blue,
                    Colors.purple,
                  ],
                  numberOfParticles: 2,
                  emissionFrequency: 0.5,
                  gravity: 0.7,
                  shouldLoop: true,
                ),
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
          title: "Kepler-App",
          home: home,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: keplerColorBlue,
              brightness: (_prefs.darkTheme) ? Brightness.dark : Brightness.light,
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

  @override
  void initState() {
    _load();
    super.initState();
  }

  @override
  void dispose() {
    globalConfettiController
      ..stop()
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    deviceInDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    super.didChangeDependencies();
  }
}
