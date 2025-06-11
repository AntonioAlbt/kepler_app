// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2023-2025 Antonio Albert

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

import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_system_proxy/flutter_system_proxy.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kepler_app/changelog.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/introduction.dart';
import 'package:kepler_app/libs/checks.dart';
import 'package:kepler_app/libs/custom_events.dart';
import 'package:kepler_app/libs/dynamic_data.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/proxy.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/tasks.dart';
import 'package:kepler_app/libs/filesystem.dart' as fs;
import 'package:kepler_app/loading_screen.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/about.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/lernsax/pages/files_page.dart';
import 'package:kepler_app/tabs/school/news_data.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

/// Damit ich in dieser Datei noch ohne Consumer auf die Datenquellen zugreifen kann,
/// werden sie hier als lokale, finale Objekte initialisiert.
final _newsCache = NewsCache();
final _internalState = InternalState();
final _prefs = Preferences();
final _credStore = CredentialStore();
final _appState = AppState();
final _stuPlanData = StuPlanData();
final _lernSaxData = LernSaxData();
final _eventManager = CustomEventManager();

/// global, damit nicht jede Seite sich selbst um Konfetti kümmern muss
final ConfettiController globalConfettiController = ConfettiController();

/// wird während Ladebildschirm ausgeführt und hat vier Funktionen:
/// 1. alle Datenquellen vom Speicher laden
/// 2. Hintergrund-Task für Benachrichtungen initialisieren
/// 3. neue News abfragen und Infos speichern
/// 4. zu alte Stundenplan-Daten und Logs löschen
Future<void> initializeApp() async {
  final sprefs = sharedPreferences;
  /// da im NewsCache theoretisch unendlich Nachrichten gespeichert werden können, wird dieser
  /// in einer Datei gespeichert - der Benutzer kann diese Datei löschen, wenn sie ihm zu groß wird (nur Android),
  /// da es in dem extra dafür vorgesehenen Cache-Ordner gespeichert wird
  if (await fs.fileExists(await newsCacheDataFilePath)) {
    final data = await fs.readFile(await newsCacheDataFilePath);
    if (data != null) _newsCache.loadFromJson(data);
  }
  /// für die Credentials werden intern auch die SharedPreferences verwendet, aber mithilfe des Paketes
  /// flutter_secure_storage wird es in den SharedPreferences verschlüsselt gespeichert (der Schlüssel gleich mit dazu)
  if (await securePrefs.containsKey(key: credStorePrefKey)) {
    _credStore.loadFromJson((await securePrefs.read(key: credStorePrefKey))!);
  }
  /// da InternalState nur sehr klein ist, wird es direkt als JSON in den SharedPreferences gespeichert
  /// die anderen Datenquellen sind alle etwas oder sehr viel größer - sie könnten zwar auch in den SPrefs
  /// gespeichert werden, damit wird aber das Laden und Speichern ineffizienter
  if (sprefs.containsKey(internalStatePrefsKey)) {
    _internalState.loadFromJson(sprefs.getString(internalStatePrefsKey)!);
  }
  // in Datei gespeichert (StuPlanData)
  if (await fs.fileExists(await stuPlanDataFilePath)) {
    final data = await fs.readFile(await stuPlanDataFilePath);
    if (data != null) _stuPlanData.loadFromJson(data);
  }
  // in Datei gespeichert (LernSaxData)
  if (await fs.fileExists(await lernSaxDataFilePath)) {
    final data = await fs.readFile(await lernSaxDataFilePath);
    if (data != null) _lernSaxData.loadFromJson(data);
  }
  // in Datei gespeichert (CustomEventsManager)
  if (await fs.fileExists(await customEventDataFilePath)) {
    final data = await fs.readFile(await customEventDataFilePath);
    if (data != null) _eventManager.loadFromJson(data);
  }

  /// Bei iOS werden die Credentials auch nach Deinstallation der App noch in der System-Keychain gespeichert, was
  /// zu Instabilität führen kann. Da der Benutzer, wenn introShown == false, sowieso noch keine Daten im CredStore
  /// gespeichert haben sollte, wird der dann zur Sicherheit beim Öffnen geleert - es könnte ja auch das Öffnen
  /// nach einer Reinstallation sein.
  if (!_internalState.introShown) {
    _credStore.clearData();
  }

  /// die übergebene Funktion wird vom Workmanager aufgerufen, wenn es Zeit für die Hintergrund-
  /// Aufgaben-Ausführung ist
  Workmanager().initialize(
    taskCallbackDispatcher,
    // isInDebugMode: kDebugMode && kDebugNotifData,
  );

  // this is only applicable to android, because for iOS I'm using the background fetch capability - it's interval is configured in the swift app delegate
  // nur Android unterstützt das direkte Ausführen von Hintergrundaufgaben - auf iOS kümmert sich immer das Betriebssystem darum
  if (Platform.isAndroid && !((await getNotifLaunchInfo())?.didNotificationLaunchApp ?? false)) {
    Workmanager().registerPeriodicTask(
      fetchTaskName,
      fetchTaskName,
      frequency: const Duration(hours: 3),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      initialDelay: const Duration(seconds: 5),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
  
  /// beim Starten der App werden hier neue News abgefragt
  /// -> falls schon alte vorhanden: nur neue abfragen (loadAllNewNews) und dann speichern
  /// -> sonst: einfach eine Seite aktuelle News laden und speichern
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

  await _stuPlanData.updateWidgets(_appState.userType == UserType.teacher);

  await DynamicData.init();
}

/// allererster Schritt, noch bevor Flutter die App selbst initialisiert
/// lädt die Preferences (Einstellungen) des Benutzers, damit der Ladebildschirm falls nötig im Dark Mode
/// angezeigt werden kann
Future<void> preInitApp() async {
  sharedPreferences = await SharedPreferences.getInstance();
  final sprefs = sharedPreferences;
  if (sprefs.containsKey(prefsPrefKey)) _prefs.loadFromJson(sprefs.getString(prefsPrefKey)!);
  await IndiwareDataManager.createDataDirIfNecessary();
}

/// Hauptfunktion - wird beim Starten der App ausgeführt
void main() async {
  /// damit die Datumsformatierung geladen werden kann, müssen erst die Grundservices von Flutter hiermit geladen werden
  WidgetsFlutterBinding.ensureInitialized();
  /// alle Datumsformatierungen für alle Sprachen laden
  initializeDateFormatting();

  /// Logging für die App initialisieren
  /// damit Log-Ausgaben dann in die entsprechenden Dateien gespeichert werden können
  await KeplerLogging.initLogging();
  /// beim Starten der App (bzw. Ausführen dieser Funktion main())
  logInfo("startup", "--- LOG INIT ---");
  /// damit alle internen Flutter-Fehler (etwa bei Darstellungsfehlern oder Widgetfehlern) auch geloggt werden,
  /// registriert sich die App hiermit als Fehler-Handler
  KeplerLogging.registerFlutterErrorHandling();

  /// erster "länger dauernder" Ausführungsschritt, lädt Benutzereinstellungen
  /// muss separat vor Anzeige Ladebildschirm passieren, damit das Theme geladen wird
  /// (damit Ladebildschirm wenn gewünscht im Darkmode angezeigt wird)
  await preInitApp();

  /// wenn ein Widget beim Rendern oder Erstellen einen Fehler wirft, verwendet Flutter diesen Builder, um stattdessen
  /// das erstellt Fehlerwidget anzuzeigen (normalerweise wird im Release-Modus nur ein grauer Bildschirm angezeigt,
  /// dabei weiß der Benutzer allerdings nicht, was los ist)
  /// - im Debug-Modus soll trotzdem der Fehler angezeigt werden
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final exception = details.exception;
    return ErrorWidget.withDetails(
      message: kDebugMode ? "Error when rendering:\n${details.exceptionAsString()}" : "Oh nein :(\n\nEs ist ein Fehler beim Darstellen aufgetreten.\nBitte kontaktiere den Ersteller der App (siehe \"Feedback & Kontakt\" in der Seitenleiste) bzw. schreibe eine E-Mail an $creatorMail.",
      error: exception is FlutterError ? exception : null,
    );
  };

  /// Der folgende Block an Code kümmert sich um das Einrichten vom Proxy, wie es vom System vorgegeben wird.
  /// Dies ist nötig, da auf Schul-iPads im Schul-WLAN immer ein Proxy zum Internetzugriff verwendet werden muss.
  logDebug("proxy", "proxy: ${await FlutterSystemProxy.findProxyFromEnvironment("https://www.lernsax.de")}");
  HttpOverrides.global = ProxyHttpOverrides();

  /// Hier beginnt die große Magie!
  /// Die App wird initialisiert, und mit runApp wird Flutter mitgeteilt, dass es jetzt dieses
  /// Widget auf der Anzeigefläche rendern soll.
  runApp(const MyApp());
}

/// Name noch von ursprünglichem Vorschlag von Flutter
/// ist das oberste Widget und dient aktuell nur zur Prüfung auf eine unterstützte Plattform
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // throw ""; // Test for new ErrorWidget
    if (Platform.isIOS || Platform.isAndroid) {
      return const KeplerApp();
    } else {
      return const Center(
        child: Text("Gerät nicht unterstüzt."),
      );
    }
  }
}

/// Widget, was beim Initialisieren den Changelog der App lädt und anzeigt
class BackgroundInfoLoader extends StatefulWidget {
  final Widget child;

  const BackgroundInfoLoader({super.key, required this.child});

  @override
  State<BackgroundInfoLoader> createState() => _BackgroundInfoLoaderState();
}

class _BackgroundInfoLoaderState extends State<BackgroundInfoLoader> {
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

    if (DynamicData.available && DynamicData.serverTooNew && mounted && !internal.infosShown.contains("app_too_old_for_dynamic")) {
      await showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Text("App veraltet"),
        content: Text("Diese Version der Kepler-App ist zu alt, um dynamische Daten zu unterstützen. Bitte die App aktualisieren."),
      ));
      internal.infosShown.add("app_too_old_for_dynamic");
    }

    if (DynamicData.enabled && mounted) {
      final latestUpdate = DynamicData.status!.appVersion.code;
      if (internal.lastVersionUpdateReminderShown < latestUpdate && currentVersion < latestUpdate) {
        await showDialog(context: context, builder: (ctx) => AlertDialog(
          title: Text("Update verfügbar"),
          content: Text("Es ist ein Update mit neuen Features oder Verbesserungen für die Kepler-App im ${(Platform.isAndroid) ? "Play" : "App"} Store verfügbar."),
          actions: [
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(
                  Platform.isAndroid
                      ? "https://play.google.com/store/apps/details?id=de.keplerchemnitz.kepler_app"
                      : "https://apps.apple.com/de/app/kepler-app/id6499428205",
                ),
                mode: LaunchMode.externalNonBrowserApplication,
              ),
              child: Text("Im ${(Platform.isAndroid) ? "Play" : "App"} Store öffnen"),
            ),
          ],
        ));
        internal.lastVersionUpdateReminderShown = latestUpdate;
      }
    }

    /// erfasst letzte angezeigte Version, damit nur bei Aktualisierungen alle neuen
    /// Änderungen angezeigt werden
    if (internal.lastChangelogShown < 0) internal.lastChangelogShown = currentVersion;
    final lastVersion = internal.lastChangelogShown;
    if (computeChangelog(currentVersion, lastVersion).isNotEmpty && mounted) {
      showDialog(context: context, builder: (ctx) => getChangelogDialog(currentVersion, lastVersion, ctx) ?? const AlertDialog());
      internal.lastChangelogShown = currentVersion;
    }
  }
}

/// teilweise muss in Funktionen/Bereichen, die keinen (geeigneten) Kontext haben, mit Provider.of auf Daten zugegriffen,
/// Aspekte des Scaffolds (z.B. SnackBars) verändert oder neue Dialoge angezeigt werden
/// damit dies auch in derartigen Bereichen passieren kann, wird ein "globaler" Kontext bereitgestellt, der überall
/// verwendet werden kann - die Verwendung sollte aber auf ein Minimum beschränkt werden! eigentlich überall
/// sind vor allem Daten von Provider.of auch mit dem lokalen Kontext erreichbar
/// -> Key wird an das Scaffold mit dem Drawer angehangen
final globalScaffoldKey = GlobalKey<ScaffoldState>();
/// Direktzugriff auf Kontext, Vermeidung von sonst Verwendung "!" für Erzwingung nicht-null bei jeder Verwendung
BuildContext get globalScaffoldContext => globalScaffoldKey.currentContext!;
/// der State wird für Scaffold-Funktionen wie das Ein-/Ausblenden des Drawers benötigt
ScaffoldState get globalScaffoldState => globalScaffoldKey.currentState!;


/// primäres App-Widget
class KeplerApp extends StatefulWidget {
  const KeplerApp({super.key});

  @override
  State<KeplerApp> createState() => _KeplerAppState();
}

/// Hauptwidget-State für die Kepler-App
class _KeplerAppState extends State<KeplerApp> with WidgetsBindingObserver {
  UserType utype = UserType.nobody;
  bool isStuplanInvalid = false;
  bool isLernsaxInvalid = false;

  /// "berechnet" den Benutzertyp basierend auf:
  /// - vergangener Zeit seit letzer Überprüfung
  /// - nur, wenn Benutzer zuletzt angemeldet war
  /// Sowohl LernSax als auch Indiware werden separat überprüft, und nur für den Service, für den Fehler auftreten,
  /// werden die Anmeldedaten neu abgefragt.
  /// Auch alternative LS-Logins werden überprüft und, falls ungültig, mit einem Hinweis entfernt.
  /// Damit auch bei fehlender Internetverbindung die App verwendet werden kann, wird der Benutzer im InternalState
  /// zwischengespeichert.
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
      /// wenn kein Internet -> annehmen, Benutzertyp hat sich nicht geändert
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

      /// seperate Liste, damit i nicht auf einmal nicht mehr auf alternativeLSLogins passt
      final toRemove = <int>[];
      /// alle alternativen LS-Logins auch überprüfen
      for (var i = 0; i < _credStore.alternativeLSLogins.length; i++) {
        final (online, check) = await confirmLernSaxCredentials(_credStore.alternativeLSLogins[i], _credStore.alternativeLSTokens[i]);
        if (!online) break;
        if (check != true) {
          toRemove.add(i);
          showSnackBar(text: "Fehler beim Authentifizieren mit LernSax-Konto ${_credStore.alternativeLSLogins[i]}. Es wurde entfernt.");
        }
      }
      for (final remove in toRemove) {
        _credStore.removeAlternativeLSUser(remove);
      }

      /// wenn Check fehlschlägt -> annehmen, Benutzertyp hat sich nicht geändert
      if (check == null) {
        showSnackBar(textGen: (sie) => "Fehler beim Kommunizieren mit LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden? Die App kann nicht auf aktuelle Daten zugreifen.");
        return _internalState.lastUserType ?? UserType.nobody;
      } else {
        final ut = await determineUserType(_credStore.lernSaxLogin!, _credStore.lernSaxToken!);
        return ut;
      }
    }
    return UserType.nobody;
  }

  /// lädt die App und kümmert sich dabei um die Initialisierung von verschiedenen anderen Funktionen:
  /// - überprüft und "berechnet" Benutzertyp
  /// - zeigt die App-Einleitungs-InfoScreens an, wenn nötig
  /// - geht mit Fehlern bei der Überprüfung der Einloggdaten um
  /// - überprüft die Benachrichtigungsberechtigung und fragt sie, wenn nötig, erneut an
  /// - aktualisiert die Stundenplan-Metadaten
  /// - überprüft, ob die App über eine Benachrichtigung gestartet wurde und geht dementsprechenden damit um
  // returns: the text to display in a snackbar, if not null; if text starts with "Achtung! " -> show as error
  Future<String?> _load() async {
    String? output;

    await initializeApp();
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

    final launchInfo = await getNotifLaunchInfo();
    if (launchInfo != null && launchInfo.didNotificationLaunchApp && launchInfo.notificationResponse != null && launchInfo.notificationResponse!.payload != null) {
      switch (launchInfo.notificationResponse!.payload!) {
        case newsNotificationKey:
          startingNavPageIDs = [NewsPageIDs.main, NewsPageIDs.news];
          break;
        case eventNotificationKey:
        case stuPlanNotificationKey:
          startingNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
          break;
      }
    }

    if (Platform.isAndroid) {
      final wsp = await HomeWidget.getWidgetData<String>("start_page");
      switch (wsp) {
        case "stuplan":
          startingNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
          break;
      }
      await HomeWidget.saveWidgetData("start_page", null);
    }

    setState(() => _loading = false);

    return output;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      final wsp = await HomeWidget.getWidgetData<String>("start_page");
      switch (wsp) {
        case "stuplan":
          /// Da context hier wirklich vom höchsten Widget ist, geht context.read<...>() noch nicht -> aber in main.dart kann
          /// noch direkt auf alle Provider zugegriffen werden
          // ignore: use_build_context_synchronously
          _appState.selectedNavPageIDs = [StuPlanPageIDs.main, StuPlanPageIDs.yours];
          break;
      }
      await HomeWidget.saveWidgetData("start_page", null);
    }
  }

  bool _loading = true;
  InfoScreenDisplay? introductionDisplay;

  List<String>? startingNavPageIDs;

  @override
  Widget build(BuildContext context) {
    /// der MultiProvider stellt (wie der Name schon sagt) mehrere Datenquellen für die darunterliegenden Widgets bereit
    final mainWidget = Consumer<AppState>(
      key: Key("mainWidget"),
      builder: (context, state, _) {
        final index = state.selectedNavPageIDs;
        final selectedNavEntry = currentlySelectedNavEntry(context);
        return BackgroundInfoLoader(
          // ignore: deprecated_member_use
          child: PopScope(
            /// der PopScope fängt das Schließen der aktuellen Route (hier: der App allgemein) ab und
            /// verhindert es abhängig vom Wert von canPop.
            /// (zusätzlich wird nach jedem (versuchten) Schließen das Callback aufgerufen)
            canPop: state.infoScreen == null,
            onPopInvokedWithResult: (popped, _) {
              if (state.infoScreen != null) {
                if (infoScreenState.tryCloseCurrentScreen()) {
                  state.clearInfoScreen();
                }
              }
            },
            child: Stack(
              children: [
                PopScope(
                  /// damit beim Durchführen von Zurück auf einer Unterseite, die nicht die ausgewählte Startseite ist,
                  /// nicht die App geschlossen wird, sondern auf die ausgewählte Startseite umgeleitet wird,
                  /// wird das Schließen-Ereignis hier abgefangen und das Schließen verhindert
                  canPop: listEquals(_appState.selectedNavPageIDs, _prefs.startNavPageIDs),
                  onPopInvokedWithResult: (popped, force) {
                    /// alle PopScopes werden aufgerufen, wenn der Benutzer die Zurück-Aktion ausführt -> auf der Dateien-
                    /// Seite wird dies aber seperat gehandled, also nur auf die Startseite zurückkehren, wenn es direkt
                    /// vom Code so bestimmt wird (z.B. mit Navigator.pop(context, true))
                    if (_appState.selectedNavPageIDs.contains(LernSaxPageIDs.files) && lsFoldersPageKey.currentState?.path.isEmpty != true) return;

                    if (!popped) _appState.selectedNavPageIDs = _prefs.startNavPageIDs;
                  },
                  child: Scaffold(
                    key: globalScaffoldKey,
                    appBar: AppBar(
                      /// als Titel wird der Titel der aktuellen Seite gewählt (zu finden im Label vom ausgewählten
                      /// Navigationseintrag)
                      title: (index.first == PageIDs.home) ? const Text("Kepler-App")
                        : selectedNavEntry?.label,
                      /// wegen mehreren AppBars darf sich die Farbe beim Scrollen nicht verändern -> Elevation ist gleich
                      scrolledUnderElevation: 5,
                      elevation: 5,
                      // this is so the two appbars in that page seem like theyre one
                      /// auf manchen Seiten wird eine weitere AppBar angezeigt, die beim Scrollen ihre Farbe verändert
                      /// damit sie aber nicht heller wird als die Haupt-AppBar, wird hier die Schattenfarbe angepasst
                      /// -> die Liste muss immer händisch angepasst werden, wenn auf einer Seite eine AppBar hinzugefügt wird!
                      shadowColor: ([StuPlanPageIDs.classPlans, StuPlanPageIDs.teacherPlan, StuPlanPageIDs.roomPlans, LernSaxPageIDs.tasks].contains(state.selectedNavPageIDs.last)) ? const Color(0x0529323b) : null,
                      actions: selectedNavEntry?.navbarActions,
                    ),
                    /// eigener Drawer für die Kepler-App - zeigt auch das Widget für den aktuellen Tab an
                    drawer: TheDrawer(
                      selectedIndex: index.join("."),
                      onDestinationSelected: (val) {
                        state.selectedNavPageIDs = val.split(".");
                      },
                      entries: destinations,
                      /// Teiler, entweder vor FFJKG oder vor Einstellungen einfügen, je nachdem, was sichtbar ist
                      dividerIDPriority: const [FFJKGPageIDs.main, PageIDs.settings],
                    ),
                    body: tabs[index.first] ?? const Text("Unbekannte Seite."),
                  ),
                ),
                /// Regenbogenkonfetti ist über die gesamte Haupt-App-Oberfläche gelegt (ist damit immer sichtbar)
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
                /// InfoScreens werden über der Haupt-App-Oberfläche angezeigt
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 100),
                  child: state.infoScreen,
                ),
              ],
            ),
          ),
        );
      },
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
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => _appState
                ..infoScreen = introductionDisplay
                ..userType = utype
                ..selectedNavPageIDs = (){
                  /// damit beim Durchführen des Intros nicht schon im Hintergrund Daten geladen werden,
                  /// wird der Navigationsindex hier auf eine nicht existente Seite gesetzt.
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
            ChangeNotifierProvider(
              create: (_) => _eventManager,
            ),
          ],
          child: MaterialApp(
            title: "Kepler-App",
            home: home,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: keplerColorBlue,
                brightness: (_prefs.darkTheme) ? Brightness.dark : Brightness.light,
              ),
              // ignore: deprecated_member_use
              progressIndicatorTheme: ProgressIndicatorThemeData(year2023: false),
            ),
          ),
        );
      },
      /// AnimatedSwitcher sorgt für eine glatte Überblendung zwischen Widgets
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: (_loading) ? loadingWidget : mainWidget,
      ),
    );
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
    });
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    globalConfettiController
      ..stop()
      ..dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// wird aufgerufen, wenn der Benutzer das Farbschema vom Betriebssystem ändert
  /// - aber MediaQuery gibt hier noch das alte Farbschema zurück!?
  @override
  void didChangePlatformBrightness() {
    if (Platform.isAndroid) {
      deviceInDarkMode = MediaQuery.platformBrightnessOf(context) == Brightness.light;
    } else if (Platform.isIOS) {
      deviceInDarkMode = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    super.didChangePlatformBrightness();
  }

  /// wird nach Start von App aufgerufen -> erst hier kann deviceInDarkMode initialisiert werden
  @override
  void didChangeDependencies() {
    deviceInDarkMode = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    super.didChangeDependencies();
  }
}
