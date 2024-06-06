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

import 'dart:io';
import 'dart:math';

import 'package:appcheck/appcheck.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kepler_app/changelog.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/introduction.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/tasks.dart';
import 'package:kepler_app/libs/filesystem.dart' as fs;
import 'package:kepler_app/loading_screen.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/school/news_data.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
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
    // isInDebugMode: kDebugMode && kDebugNotifData,
  );
  // this is only applicable to android, because for iOS I'm using the background fetch capability - it's interval is configured in the swift app delegate
  if (Platform.isAndroid && !((await getNotifLaunchInfo())?.didNotificationLaunchApp ?? false)) {
    // try {
    //   // add this because users on previous versions of the app with the old "fetch_news" task will have both running
    //   Workmanager().cancelByUniqueName("fetch_news");
    // } on Exception catch (_) {}
    Workmanager().registerPeriodicTask(
      fetchTaskName,
      fetchTaskName,
      frequency: const Duration(hours: 3),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      initialDelay: const Duration(seconds: 5),
      constraints: Constraints(networkType: NetworkType.connected),
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
  if (!_prefs.enableInfiniteStuPlanScrolling) await IndiwareDataManager.removeOldCacheFiles();
  final del = await KeplerLogging.deleteLogsOlderThan(DateTime.now().subtract(Duration(days: _prefs.logRetentionDays)));
  if (kDebugMode) print("deleted logs for the following days: $del");
}

Future<void> prepareApp() async {
  sharedPreferences = await SharedPreferences.getInstance();
  final sprefs = sharedPreferences;
  if (sprefs.containsKey(prefsPrefKey)) _prefs.loadFromJson(sprefs.getString(prefsPrefKey)!);
  await IndiwareDataManager.createDataDirIfNecessary();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting();
  // LicenseRegistry.addLicense(() => Stream.value(const LicenseEntryWithLineBreaks(["kepler_app"], gplv3LicenseText)));

  await KeplerLogging.initLogging();
  logInfo("startup", "--- LOG INIT ---");
  KeplerLogging.registerFlutterErrorHandling();

  await prepareApp();
  runApp(const MyApp());
}

void showLoginScreenAgain({ bool clearData = true, bool closeable = true }) {
  final ctx = globalScaffoldContext;

  if (Provider.of<CredentialStore>(ctx, listen: false).lernSaxLogin == lernSaxDemoModeMail) {
    showDialog(context: ctx, builder: (ctx) => const AlertDialog(
      title: Text("Demo-Login"),
      content: Text("Da der Demo-Login verwendet wurde, muss die App zum Abmelden neu installiert werden."),
    ));
    return;
  }

  if (clearData) {
    Provider.of<CredentialStore>(ctx, listen: false).clearData();
    // Provider.of<NewsCache>(ctx, listen: false).clearData();
    // Provider.of<StuPlanData>(ctx, listen: false).clearData();
    Provider.of<InternalState>(ctx, listen: false).introShown = false;
    Provider.of<Preferences>(ctx, listen: false).startNavPage = PageIDs.home;
  }
  Provider.of<AppState>(ctx, listen: false)
    ..selectedNavPageIDs = [PageIDs.home] // isn't neccessarily the default screen (because of prefs), but idc
    ..infoScreen = InfoScreenDisplay(
      infoScreens: closeable ? loginAgainScreens : loginAgainScreensUncloseable,
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

final absolutelyTopKeyForToplevelDialogsOnly = GlobalKey();

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
  } catch (e, s) {
    logCatch("indiware-check", e, s);
    return null;
  }
}

Future<String?> checkAndUpdateSPMetaData(String vpHost, String vpUser, String vpPass, UserType utype, StuPlanData stuPlanData) async {
  List<DateTime>? updatedFreeDays;
  String? output;
  if (utype == UserType.teacher && stuPlanData.availableTeachers != null && stuPlanData.lastAvailTeachersUpdate.difference(DateTime.now()).abs().inDays >= 14) {
    final (data, _) = await getLehrerXmlLeData(vpHost, vpUser, vpPass);
    if (data != null) {
      stuPlanData.loadDataFromLeData(data);
      // check if selected teacher code doesn't exist anymore (because the school removed it)
      if (stuPlanData.selectedTeacherName != null && data?.teachers.map((t) => t.teacherCode).contains(stuPlanData.selectedTeacherName!) == false) {
        stuPlanData.selectedTeacherName = null;
        output ??= "Achtung! Der gewählte Lehrer ist nicht mehr in den Schuldaten vorhanden. Der Stundenplan muss neu eingerichtet werden.";
      }
      updatedFreeDays = data.holidays.holidayDates;
    } else {
      output ??= "Hinweis: Die Stundenplan-Daten sind nicht mehr aktuell. Bitte mit dem Internet verbinden.";
    }
  } else if (
    utype != UserType.nobody &&
    (
      (stuPlanData.availableClasses != null && stuPlanData.lastAvailClassesUpdate.difference(DateTime.now()).abs().inDays >= 14)
      || (stuPlanData.availableSubjects.isNotEmpty && stuPlanData.lastAvailSubjectsUpdate.difference(DateTime.now()).abs().inDays >= 14)
    )
  ) {
    final (rawData, _) = await getKlassenXML(vpHost, vpUser, vpPass);
    if (rawData != null) {
      final data = xmlToKlData(rawData);
      stuPlanData.loadDataFromKlData(data);
      // check if selected class name doesn't exist anymore (because the school removed it)
      if (stuPlanData.selectedClassName != null && data?.classes.map((t) => t.className).contains(stuPlanData.selectedClassName!) == false) {
        stuPlanData.selectedClassName = null;
        output ??= "Achtung! Die gewählte Klasse ist nicht mehr in den Schuldaten vorhanden. Der Stundenplan muss neu eingerichtet werden.";
      }
      IndiwareDataManager.setKlassenXmlData(rawData);
      updatedFreeDays = data.holidays.holidayDates;
    } else {
      output ??= "Hinweis: Die Stundenplan-Daten sind nicht mehr aktuell. Bitte mit dem Internet verbinden.";
    }
  }
  if (stuPlanData.lastHolidayDatesUpdate.difference(DateTime.now()).abs().inDays >= 14) {
    if (updatedFreeDays != null) {
      stuPlanData.holidayDates = updatedFreeDays;
      stuPlanData.lastHolidayDatesUpdate = DateTime.now();
    } else {
      final (rawData, _) = await getKlassenXML(vpHost, vpUser, vpPass);
      if (rawData != null) {
        final data = xmlToKlData(rawData);
        stuPlanData.holidayDates = data.holidays.holidayDates;
        stuPlanData.lastHolidayDatesUpdate = DateTime.now();
        IndiwareDataManager.setKlassenXmlData(rawData);
      } else {
        output ??= "Hinweis: Die Liste der schulfreien Tage ist nicht mehr aktuell. Bitte mit dem Internet verbinden.";
      }
    }
  }
  return output;
}

class OnStartLoader extends StatefulWidget {
  final Widget child;

  const OnStartLoader({super.key, required this.child});

  @override
  State<OnStartLoader> createState() => _OnStartLoaderState();
}

class _OnStartLoaderState extends State<OnStartLoader> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final internal = Provider.of<InternalState>(context, listen: false);
    final version = await PackageInfo.fromPlatform();
    final currentVersion = int.parse(version.buildNumber);
    final lastVersion = internal.lastChangelogShown;
    if (currentVersion > lastVersion && mounted) {
      showDialog(context: context, builder: (ctx) => getChangelogDialog(currentVersion, lastVersion, ctx) ?? const AlertDialog());
      internal.lastChangelogShown = currentVersion;
    }
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

  // returns: the text to display in a snackbar, if not null; if text starts with "Achtung! " -> show as error
  Future<String?> _load() async {
    String? output;

    final t1 = DateTime.now();
    await loadAndPrepareApp();
    utype = await calcUT();
    _internalState.lastUserType = utype;

    if (!_internalState.introShown) {
      // _appState.selectedNavPageIDs = ["intro-non-existent"]; // -> is done when setting the selectedNavPageIDs
      _appState.navPagesToOpenAfterNextISClose = [PageIDs.home];
      introductionDisplay = InfoScreenDisplay(
        infoScreens: introScreens,
      );
    } else {
      if (isLernsaxInvalid || isStuplanInvalid) {
        final both = isLernsaxInvalid && isStuplanInvalid;
        output = "Die Anmeldedaten für ${isLernsaxInvalid ? "LernSax" : ""}${both ? " und " : ""}${isStuplanInvalid ? "den Stundenplan" : ""} sind ungültig. Bitte erneut anmelden.";
        introductionDisplay = InfoScreenDisplay(
          infoScreens: [
            if (isLernsaxInvalid) lernSaxLoginAgainScreen(false),
            if (isStuplanInvalid) stuPlanLoginAgainScreen,
            finishScreen,
          ],
        );
      }
      if (!await checkNotificationPermission() && _prefs.enabledNotifs.isNotEmpty) {
        await requestNotificationPermission();
      }
    }

    final vpUser = _credStore.vpUser, vpPass = _credStore.vpPassword, vpHost = _credStore.vpHost ?? baseUrl;
    if (vpUser != null && vpPass != null && vpHost != indiwareDemoHost) {
      output ??= await checkAndUpdateSPMetaData(vpHost, vpUser, vpPass, utype, _stuPlanData);
    }

    final mdif = DateTime.now().difference(t1).inMilliseconds;
    if (kDebugMode) print("Playing difference: $mdif");
    // if (mdif < _loadingAnimationDuration) await Future.delayed(Duration(milliseconds: _loadingAnimationDuration - mdif));
    // await Future.delayed(const Duration(seconds: 100));

    final launchInfo = await getNotifLaunchInfo();
    if (launchInfo != null && launchInfo.didNotificationLaunchApp && launchInfo.notificationResponse != null && launchInfo.notificationResponse!.payload != null) {
      switch (launchInfo.notificationResponse!.payload!) {
        case newsNotificationKey:
          startingNavPageIDs = [NewsPageIDs.main, NewsPageIDs.news];
          break;
        case stuPlanNotificationKey:
          startingNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
          break;
      }
    }

    setState(() => _loading = false);

    return output;
  }

  bool _loading = true;
  InfoScreenDisplay? introductionDisplay;

  List<String>? startingNavPageIDs;

  @override
  Widget build(BuildContext context) {
    final mainWidget = MultiProvider(
      key: absolutelyTopKeyForToplevelDialogsOnly,//const Key("mainWidget"),
      providers: [
        ChangeNotifierProvider(
          create: (_) => _appState
            ..infoScreen = introductionDisplay
            ..userType = utype
            ..selectedNavPageIDs = (){
              if (introductionDisplay != null) return ["intro-non-existent"];
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
        // PopScopes are weird in comparison to WillPopScope-s, if anyone wants to update them anyway, have fun
        // maybe helpful for async: https://stackoverflow.com/questions/77500680/willpopscope-is-deprecated-after-flutter-3-12
        return OnStartLoader(
          // ignore: deprecated_member_use
          child: WillPopScope(
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
                // ignore: deprecated_member_use
                WillPopScope(
                  onWillPop: () async {
                    if (!listEquals(_appState.selectedNavPageIDs, _prefs.startNavPageIDs)) {
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
                        : currentlySelectedNavEntry(context)?.label,
                      scrolledUnderElevation: 5,
                      elevation: 5,
                      // this is so the two appbars in that page seem like theyre one
                      shadowColor: ([StuPlanPageIDs.classPlans, StuPlanPageIDs.teacherPlan, StuPlanPageIDs.roomPlans, LernSaxPageIDs.tasks].contains(state.selectedNavPageIDs.last)) ? const Color(0x0529323b) : null,
                      actions: currentlySelectedNavEntry(context)?.navbarActions,
                    ),
                    drawer: TheDrawer(
                      selectedIndex: index.join("."),
                      onDestinationSelected: (val) {
                        state.selectedNavPageIDs = val.split(".");
                      },
                      entries: destinations,
                      dividers: const [6],
                    ),
                    body: tabs[index.first] ?? const Text("Unbekannte Seite."),
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

  static const oldAndroidPkgId = "dev.gamer153.kepler_app";
  void checkAndNotifyForOldPkgId() async {
    if (!Platform.isAndroid) return;
    await Future.delayed(const Duration(seconds: 1));
    try {
      final res = await AppCheck.checkAvailability(oldAndroidPkgId);
      if (res == null) throw Exception();
      
      showDialog(context: absolutelyTopKeyForToplevelDialogsOnly.currentContext!, builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text("Alte App-Version gefunden!"),
          content: const Text("Die Paket-ID der App hat sich mit Version 2.0.0 geändert - dadurch sind alle Daten weg, und die App ist jetzt zweimal installiert. Bitte deinstalliere die alte Variante der App (bis Version 1.8.3).\n\nDu kannst die App erst verwenden, nachdem die alte Version entfernt ist."),
          actions: [
            TextButton(onPressed: () => SystemNavigator.pop(), child: const Text("Ok, ich deinstalliere die alte Version")),
          ],
        ),
      ));
    } catch (_) {}
  }

  @override
  void initState() {
    _load().then((text) {
      if (text != null) {
        if (text.startsWith("Achtung! ")) {
          showSnackBar(text: text, clear: true, error: true, duration: const Duration(seconds: 5));
        } else {
          showSnackBar(text: text);
        }
      }
      
      checkAndNotifyForOldPkgId();
    });
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
