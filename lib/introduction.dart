import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/notifications.dart';

import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/privacy_policy.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final introScreens = [welcomeScreen, lernSaxLoginScreen, stuPlanLoginScreen, notificationInfoScreen, finishScreen];
final loginAgainScreens = [lernSaxLoginAgainScreen(true), stuPlanLoginAgainScreen, finishScreen];

const welcomeScreen = InfoScreen(
  infoTitle: Text("Willkommen in der Kepler-App!"),
  infoText: WelcomeScreenMain(),
  closeable: false,
  infoImage: Text("🎉", style: TextStyle(fontSize: 48)),
);

const lernSaxLoginScreen = InfoScreen(
  infoTitle: Text("LernSax-Anmeldung"),
  infoText: LernSaxScreenMain(),
  closeable: false,
  infoImage: Icon(Icons.laptop, size: 48),
);

InfoScreen lernSaxLoginAgainScreen(bool closeable) => InfoScreen(
  infoTitle: const Text("LernSax-Anmeldung"),
  infoText: const LernSaxScreenMain(again: true),
  closeable: closeable,
  infoImage: const Icon(Icons.laptop, size: 48),
);

const stuPlanLoginScreen = InfoScreen(
  infoTitle: Text("Stundenplan-Anmeldung"),
  infoText: StuPlanScreenMain(),
  closeable: false,
  infoImage: Icon(Icons.list_alt, size: 48),
);

const stuPlanLoginAgainScreen = InfoScreen(
  infoTitle: Text("Stundenplan-Anmeldung"),
  infoText: StuPlanScreenMain(again: true),
  closeable: false,
  infoImage: Icon(Icons.list_alt, size: 48),
);

const notificationInfoScreen = InfoScreen(
  infoTitle: Text("Benachrichtigungen"),
  infoText: NotifInfoScreenMain(),
  closeable: false,
  infoImage: Icon(Icons.notifications_active, size: 48),
);

final finishScreen = InfoScreen(
  infoImage: const Icon(Icons.check_box, size: 48),
  infoTitle: const Text("Danke und willkommen!"),
  infoText: Selector<Preferences, bool>(
    selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
    builder: (context, sie, _) {
      return Column(
        children: [
          Text("Vielen Dank für ${sie ? "Ihre" : "Deine"} Anmeldung. ${sie ? "Sie können" : "Du kannst"} jetzt auf die App zugreifen."),
          ((){
            switch (Provider.of<AppState>(context, listen: false).userType) {
              case UserType.nobody:
                return const Text("Viel Spaß beim Ausprobieren!"); // we shouldn't even reach this case.
              case UserType.parent:
                return Text("Als Elternteil ${sie ? "haben Sie" : "hast Du"} Zugriff auf den Vertretungsplan für Schüler (und Eltern) und alle LernSax-Funktionen für ${sie ? "Sie" : "Dich"}.");
              case UserType.teacher:
                return Text("Als Lehrer ${sie ? "haben Sie" : "hast Du"} Zugriff auf den Vertretungsplan für Lehrer und Schüler und alle LernSax-Funktionen.");
              case UserType.pupil:
                return Text("Als Schüler ${sie ? "haben Sie" : "hast Du"} Zugriff auf den Vertretungsplan für Schüler und alle LernSax-Funktionen.");
              default: // we absolutely should not reach this case! (maybe if someone adds new UserType-s)
                return const Text("Aber irgendetwas ist schiefgelaufen... Ich schau mal schnell nach, ne?");
            }
          }()),
          Consumer<AppState>(
            builder: (context, state, _) {
              return ElevatedButton(
                onPressed: () {
                  Provider.of<InternalState>(context, listen: false).introShown = true;
                  state.clearInfoScreen();
                },
                child: const Text("Schließen"),
              );
            }
          ),
        ],
      );
    }
  ),
  onTryClose: (_, context) {
    Provider.of<InternalState>(context, listen: false).introShown = true;
    return true;
  },
  closeable: true,
);

class WelcomeScreenMain extends StatefulWidget {
  const WelcomeScreenMain({super.key});

  @override
  State<WelcomeScreenMain> createState() => _WelcomeScreenMainState();
}

class _WelcomeScreenMainState extends State<WelcomeScreenMain> {
  @override
  Widget build(BuildContext context) {
    return Consumer<Preferences>(
      builder: (context, prefs, _) {
        final mitSie = prefs.preferredPronoun == Pronoun.sie;
        return Column(
          children: [
            Text("Als erstes werden wir ${mitSie ? "Ihnen" : "Dir"} ein paar Fragen stellen, um die App für ${mitSie ? "Sie" : "Dich"} anzupassen."),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Wie ${mitSie ? "möchten Sie" : "möchtest Du"} angeredet werden?"),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RadioMenuButton(
                        value: Pronoun.sie,
                        groupValue: prefs.preferredPronoun,
                        onChanged: (val) => prefs.preferredPronoun = val!,
                        child: const Text("mit Sie"),
                      ),
                      RadioMenuButton(
                        value: Pronoun.du,
                        groupValue: prefs.preferredPronoun,
                        onChanged: (val) => prefs.preferredPronoun = val!,
                        child: const Text("mit Du"),
                      ),
                    ],
                  ),
                  const Text(
                    "Dies kann später in den Einstellungen geändert werden.",
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        infoScreenState.next();
                      },
                      child: const TextWithArrowForward(text: "Los geht's!"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class LernSaxScreenMain extends StatefulWidget {
  final bool again;

  const LernSaxScreenMain({super.key, this.again = false});

  @override
  State<LernSaxScreenMain> createState() => _LernSaxScreenMainState();
}

const lernSaxAGBLink = "https://www.lernsax.de/wws/1491042.php";
class _LernSaxScreenMainState extends State<LernSaxScreenMain> {
  late TextEditingController _mailController;
  String? _mailError;
  late TextEditingController _pwController;
  String? _pwError;

  bool _triedToEnter = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    const TextStyle link = TextStyle(color: Colors.blue, decoration: TextDecoration.underline);
    return Selector<Preferences, bool>(
      selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
      builder: (context, sie, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              (widget.again) ?
              "Bitte ${sie ? "melden Sie sich" : "melde Dich"} erneut mit ${sie ? "Ihrem" : "Deinem"} JKG-LernSax-Konto an."
              :
              "Bitte ${sie ? "melden Sie sich" : "melde Dich"} mit ${sie ? "Ihrem" : "Deinem"} JKG-LernSax-Konto an. Damit können wir bestätigen, dass ${sie ? "Sie" : "Du"} wirklich Teil unserer Schule ${sie ? "sind" : "bist"}.",
            ),
          ),
          TextField(
            controller: _mailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: "LernSax-Email-Adresse",
              errorText: _mailError,
            ),
          ),
          TextField(
            controller: _pwController,
            keyboardType: TextInputType.visiblePassword,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "LernSax-Passwort",
              errorText: _pwError,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _triedToEnter = true;
                  _mailError = checkMail();
                  _pwError = checkPW();
                });
                if (_mailError != null || _pwError != null) return;
                final mail = _mailController.text;
                final pw = _pwController.text;
                FocusScope.of(context).unfocus();
                runLogin(mail, pw, sie).then((error) {
                  if (error == null) {
                    try {
                      registerApp(mail, pw).then((data) {
                        final (online, token) = data;
                        if (!online) {
                          showSnackBar(text: "Keine Verbindung zu den LernSax-Servern möglich. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
                          return;
                        } else if (token == null) {
                          showSnackBar(text: "Fehler beim Verbinden der App. Bitte ${sie ? "versuchen Sie" : "versuche"} es später erneut.", error: true, clear: true);
                          return;
                        }
                        final credStore = Provider.of<CredentialStore>(context, listen: false);
                        credStore.lernSaxLogin = mail;
                        credStore.lernSaxToken = token;
                        if (parentTypeEndings.any((element) => mail.split("@")[0].endsWith(".$element"))) {
                          Provider.of<AppState>(context, listen: false).userType = UserType.parent;
                        }
                        showSnackBar(text: "Erfolgreich eingeloggt und verbunden.", clear: true);
                        infoScreenState.next();
                      });
                    } catch (_) {
                      showSnackBar(text: "Fehler beim Verbinden der App. Bitte ${sie ? "versuchen Sie" : "versuche"} es später erneut.", error: true, clear: true);
                    }
                  } else {
                    showSnackBar(text: error, error: true);
                  }
                });
              },
              child: const TextWithArrowForward(text: "Einloggen"),
            ),
          ),
          // don't show this again because the user already agreed
          if (!widget.again) RichText(
            textAlign: TextAlign.center,
            textScaleFactor: 1,
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: "Mit dem Fortfahren ${sie ? "stimmen Sie" : "stimmst Du"} den ",
                ),
                TextSpan(
                  text: "Datenschutzbestimmungen",
                  style: link,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Datenschutzerklärung der Kepler-App"),
                            content: const PrivacyPolicy(),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text("Schließen"),
                              ),
                            ],
                          ),
                        ),
                ),
                const TextSpan(
                  text: " dieser App und den ",
                ),
                TextSpan(
                  text: "Nutzungsbedingungen",
                  style: link,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(
                      Uri.parse(lernSaxAGBLink),
                      mode: LaunchMode.externalApplication,
                    ),
                ),
                const TextSpan(
                  text: " von LernSax zu.",
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Nicht mit LernSax anmelden?"),
                  content: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: "Wenn ${sie ? "Sie sich" : "Du dich"} nicht ${sie ? "anmelden, können Sie" : "anmeldest, kannst Du"} auf die meisten Funktionen der App nicht zugreifen.",
                        ),
                        const TextSpan(
                          text: " Dies ist vor allem für interessierte Eltern ohne LernSax-Zugang geeignet. ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: "Wirklich ohne Anmeldung fortfahren?")
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text("Nein"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text("Ja, fortfahren"),
                    ),
                  ],
                ),
              ).then((value) {
                if (value == true) {
                  Provider.of<InternalState>(context, listen: false)
                    ..introShown = true
                    ..lastUserType = UserType.nobody;
                  Provider.of<AppState>(context, listen: false)
                    ..userType = UserType.nobody
                    ..clearInfoScreen();
                  if (!widget.again) {
                    showDialog(
                      context: globalScaffoldContext,
                      builder: (context) => AlertDialog(
                        title: const Text("Benachrichtigungen?"),
                        content: const Text("Möchten Sie benachrichtigt werden, wenn neue Artikel auf der Webseite unserer Schule veröffentlicht werden?"),
                        actions: [
                          TextButton(
                            onPressed: (){
                              Provider.of<Preferences>(globalScaffoldContext, listen: false).enabledNotifs = [newsNotificationKey];
                              checkNotificationPermission().then((notifAllowed) {
                                if (notifAllowed) {
                                  Navigator.pop(context);
                                  return;
                                }
                                try {
                                  requestNotificationPermission().then((val) {
                                    if (val) {
                                      showSnackBar(textGen: (sie) => "Danke für ${sie ? "Ihre" : "Deine"} Zustimmung!");
                                    }
                                    Navigator.pop(context);
                                  });
                                } catch (_) {
                                  Navigator.pop(context);
                                }
                              });
                              
                            },
                            child: const Text("Ja, gerne"),
                          ),
                          TextButton(
                            onPressed: () {
                              Provider.of<Preferences>(globalScaffoldContext, listen: false).enabledNotifs = [];
                              Navigator.pop(context);
                            },
                            child: const Text("Nein"),
                          ),
                        ],
                      ),
                    );
                  }
                }
              });
            },
            child: const Text("Ich habe keine Anmeldedaten."),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_loading) const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Loggt ein..."),
          ),
        ],
      ),
    );
  }

  Future<String?> runLogin(String mail, String pw, bool sie) async {
    setState(() => _loading = true);
    // "online" boolean is unnecessary here because MOJKGResult.otherError
    final (_, check) = await isMemberOfJKG(mail, pw);
    setState(() => _loading = false);
    switch (check) {
      case MOJKGResult.invalidLogin:
        return "Ungültige Anmeldedaten. Bitte ${sie ? "überprüfen Sie Ihre" : "überprüfe Deine"} Eingabe.";
      case MOJKGResult.allGood:
        return null;
      case MOJKGResult.noJKGMember:
        return "${sie ? "Sie sind" : "Du bist"} kein Mitglied des JKGs.";
      case MOJKGResult.otherError:
        return "Fehler bei der Verbindung mit den LernSax-Servern.";
      case MOJKGResult.invalidResponse:
        return "Es ist ein Fehler aufgetreten. Bitte ${sie ? "versuchen Sie" : "versuche"} es später erneut.";
    }
  }

  String? checkMail() {
    if (_mailController.text.trim() == "" && _triedToEnter) {
      return "Keine E-Mail-Adresse angegeben.";
    } else if (_triedToEnter) {
      RegExp regex = RegExp(r"^[a-z]*[0-9]*(?:.(?:" + parentTypeEndings.join("|") + r"))?@jkgc\.lernsax\.de$", multiLine: true, caseSensitive: false);
      if (!regex.hasMatch(_mailController.text)) return "Ungültige LernSax-E-Mail-Adresse.";
    }
    return null;
  }

  String? checkPW() {
    if (_pwController.text.trim() == "" && _triedToEnter) {
      return "Kein Passwort angegeben.";
    }
    return null;
  }

  @override
  void initState() {
    _mailController = TextEditingController();
    _mailController.addListener(() {
      setState(() => _mailError = checkMail());
    });

    _pwController = TextEditingController();
    _pwController.addListener(() {
      setState(() => _pwError = checkPW());
    });

    super.initState();
  }

  @override
  void dispose() {
    _mailController.dispose();
    _pwController.dispose();
    super.dispose();
  }
}

class StuPlanScreenMain extends StatefulWidget {
  final bool again;

  const StuPlanScreenMain({super.key, this.again = false});

  @override
  State<StuPlanScreenMain> createState() => _StuPlanScreenMainState();
}

class _StuPlanScreenMainState extends State<StuPlanScreenMain> {
  late TextEditingController _userController;
  String? _userErr;
  late TextEditingController _pwController;
  String? _pwErr;
  late Future<bool?> _dataFuture;

  bool _triedToEnter = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) => Selector<Preferences, bool>(
        selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
        builder: (context, sie, _) => FutureBuilder(
          future: _dataFuture,
          builder: (context, datasn) {
            if (datasn.connectionState == ConnectionState.waiting) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("Wir versuchen, den Stundenplan-Login von LernSax abzufragen..."),
                  ),
                ],
              );
            }
            if (datasn.data == true) {
              return Column(
                children: [
                  Text("${sie ? "Sie wurden" : "Du wurdest"} automatisch über LernSax beim ${state.userType == UserType.teacher ? "Lehrer-" : "Schüler-"}Stundenplan angemeldet."),
                  if (state.userType == UserType.parent) Text("Damit ${sie ? "können Sie" : "kannst Du"} den Stundenplan ${sie ? "Ihres" : "Deines"} Kindes in der App abfragen."),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ElevatedButton(
                      onPressed: () {
                        final cs = Provider.of<CredentialStore>(context, listen: false);
                        determineUserType(cs.lernSaxLogin!, cs.lernSaxToken!)
                          .then((userType) {
                            Provider.of<AppState>(context, listen: false).userType = userType;
                            Provider.of<InternalState>(context, listen: false).lastUserType = userType;
                            infoScreenState.next();
                          });
                      },
                      child: const TextWithArrowForward(text: "Fortfahren"),
                    ),
                  ),
                ],
              );
            }
            if (datasn.data == false) {
              // notify the maintainer of the sentry account that something is wrong
              // but don't do anything else, just fallback to the user input
              Sentry.captureException("LSDataError: lernsax indiware auth data isn't working");
            }
            return Column(
              children: [
                const Text("Leider konnten die Daten nicht automatisch von LernSax abgefragt werden.\n"),
                Text("Bitte ${sie ? "geben Sie" : "gebe"} die Anmeldedaten für ${sie ? "Ihren" : "Deinen"} Stundenplan auf plan.kepler-chemnitz.de ${widget.again ? "erneut" : ""} ein."),
                if (state.userType == UserType.parent) Text("Da ${sie ? "Sie" : "Du"} ein Elternteil ${sie ? "sind" : "bist"}, sollten dies die Anmeldedaten des Schülerstundenplanes sein."),
                const Padding(padding: EdgeInsets.all(4)),
                TextField(
                  controller: _userController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Benutzername",
                    errorText: _userErr,
                  ),
                ),
                TextField(
                  controller: _pwController,
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Passwort",
                    errorText: _pwErr,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _triedToEnter = true;
                        _userErr = checkUser();
                        _pwErr = checkPW();
                      });
                      if (_userErr != null || _pwErr != null) return;
                      FocusScope.of(context).unfocus();
                      final username = _userController.text.trim();
                      final password = _pwController.text;
                      handleLogin(username, password, sie)
                          .then((error) {
                            if (error != null) {
                              showSnackBar(text: error, error: true, clear: true);
                            } else {
                              final cs = Provider.of<CredentialStore>(context, listen: false);
                              cs.vpUser = username;
                              cs.vpPassword = password;
                              determineUserType(cs.lernSaxLogin!, cs.lernSaxToken!)
                                .then((userType) {
                                  Provider.of<AppState>(context, listen: false).userType = userType;
                                  Provider.of<InternalState>(context, listen: false).lastUserType = userType;
                                  showSnackBar(text: "Erfolgreich angemeldet.", clear: true);
                                  infoScreenState.next();
                                });
                            }
                          });
                    },
                    child: const TextWithArrowForward(text: "Anmelden"),
                  ),
                ),
                if (_loading) const LinearProgressIndicator(),
                if (_loading) const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Meldet an..."),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  String? checkUser() => (_userController.text.trim() == "") ? "Benutzername erforderlich." : null;
  String? checkPW() => (_pwController.text.trim() == "") ? "Passwort erforderlich." : null;

  Future<String?> handleLogin(String username, String password, bool sie) async {
    try {
      setState(() => _loading = true);
      final lres = await authRequest(lUrlMLeXmlUrl(baseUrl), username, password);
      // if null, throw -> to catch block
      if (lres!.statusCode == 401) { // if teacher auth failed, try again with pupil auth
        final sres = await authRequest(sUrlMKlXmlUrl(baseUrl), username, password);
        if (sres!.statusCode == 401) return "Ungültige Anmeldedaten.";
        if (sres.statusCode != 200) return "Fehler #SP${sres.statusCode}. Bitte ${sie ? "versuchen Sie" : "versuche"} es später erneut.";
        return null;
      }
      if (lres.statusCode != 200) return "Fehler #LP${lres.statusCode}. Bitte ${sie ? "versuchen Sie" : "versuche"} es später erneut.";
      return null;
    } catch (_) {
      return "Fehler bei der Verbindung zum Vertretungsplan. Bitte ${sie ? "versuchen Sie" : "versuche"} es später erneut.";
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    _userController = TextEditingController();
    _userController.addListener(() {
      if (_triedToEnter) setState(() => _userErr = checkUser());
    });
    _pwController = TextEditingController();
    _pwController.addListener(() {
      if (_triedToEnter) setState(() => _pwErr = checkPW());
    });
    _dataFuture = tryLoadStuPlanLoginFromLSDataFile();
    super.initState();
  }

  @override
  void dispose() {
    _userController.dispose();
    _pwController.dispose();
    super.dispose();
  }
  
  /// returns:<ul>
  /// <li>null = error with finding or loading the file</li>
  /// <li>false = invalid data in file</li>
  /// <li>true = data in file works</li>
  /// </ul>
  Future<bool?> tryLoadStuPlanLoginFromLSDataFile() async {
    final creds = Provider.of<CredentialStore>(context, listen: false);
    if (creds.lernSaxToken == null || creds.lernSaxLogin == null) return null;
    // ignore the online bool because it doesn't matter - I don't show any actual error message to the user
    final (_, teacher) = await isTeacher(creds.lernSaxLogin!, creds.lernSaxToken!);
    if (teacher == null) return null;
    final (_, data) = await getLernSaxAppDataJson(creds.lernSaxLogin!, creds.lernSaxToken!, teacher);
    if (data == null || data.isTeacherData != teacher) return null;

    try {
      final lres = await authRequest(Uri.parse("${data.host}$lUrlMLeXmlPath"), data.user, data.password);
      if (lres!.statusCode != 200) throw Exception();
      return true;
    } catch (_) {
      final sres = await authRequest(Uri.parse("${data.host}$sUrlMKlXmlPath"), data.user, data.password);
      final success = sres!.statusCode == 200;
      if (success) {
        creds.vpHost = data.host;
        creds.vpUser = data.user;
        creds.vpPassword = data.password;
        showSnackBar(text: "Erfolgreich angemeldet.", clear: true);
      }
      return success;
    }
  }
}

class NotifInfoScreenMain extends StatefulWidget {
  const NotifInfoScreenMain({super.key});

  @override
  State<NotifInfoScreenMain> createState() => _NotifInfoScreenMainState();
}

class _NotifInfoScreenMainState extends State<NotifInfoScreenMain> {
  List<String> selectedNotifications = [newsNotificationKey, stuPlanNotificationKey];

  @override
  Widget build(BuildContext context) {
    return Consumer<Preferences>(
      builder: (context, prefs, _) {
        final sie = prefs.preferredPronoun == Pronoun.sie;
        return Column(
          children: [
            Text("Diese App kann ${sie ? "Ihnen" : "Dir"} Benachrichtigungen für bestimmte Dinge senden. Dafür benötigen wir ${sie ? "Ihre" : "Deine"} Zustimmung."),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Für was ${sie ? "möchten Sie" : "möchtest Du"} benachrichtigt werden?"),
                  ListView(
                    shrinkWrap: true,
                    children: [
                      CheckboxListTile(
                        value: prefs.enabledNotifs.contains(newsNotificationKey),
                        title: const Text("Neue Kepler-News"),
                        onChanged: (val) => val! ? prefs.addEnabledNotif(newsNotificationKey) : prefs.removeEnabledNotif(newsNotificationKey),
                      ),
                      CheckboxListTile(
                        value: prefs.enabledNotifs.contains(stuPlanNotificationKey),
                        title: const Text("Änderungen im Stundenplan"),
                        onChanged: (val) => val! ? prefs.addEnabledNotif(stuPlanNotificationKey) : prefs.removeEnabledNotif(stuPlanNotificationKey),
                      ),
                    ],
                  ),
                  const Text(
                    "Dies kann auch in den Einstellungen geändert werden.",
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        checkNotificationPermission().then((hasAgreed) {
                          if (!hasAgreed) {
                            requestNotificationPermission().then((agreedNow) {
                              if (agreedNow) {
                                showSnackBar(text: "Danke für ${sie ? "Ihre" : "Deine"} Zustimmung.", error: false);
                              } else {
                                showSnackBar(text: "Leider ${sie ? "haben Sie" : "hast Du"} nicht zugestimmt. Wir werden keine Benachrichtigungen senden.", error: true);
                              }
                              infoScreenState.next();
                            });
                          } else {
                            infoScreenState.next();
                          }
                        });
                      },
                      child: const TextWithArrowForward(text: "Abschließen"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<Preferences>(context, listen: false).enabledNotifs = [newsNotificationKey, stuPlanNotificationKey];
    });
    super.initState();
  }
}

class TextWithArrowForward extends StatelessWidget {
  final String text;

  const TextWithArrowForward({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(Icons.arrow_forward),
        ),
      ],
    );
  }
}
