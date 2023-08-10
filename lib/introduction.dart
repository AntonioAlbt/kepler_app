import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/lernsax.dart';

import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/privacy_policy.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

final introScreens = [welcomeScreen, lernSaxLoginScreen, stuPlanLoginScreen, finishScreen];

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

const stuPlanLoginScreen = InfoScreen(
  infoTitle: Text("Stundenplan-Anmeldung"),
  infoText: StuPlanScreenMain(),
  closeable: false,
  infoImage: Icon(Icons.list_alt, size: 48),
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
                  // const Text("Welches Aussehen soll die App verwenden?"),
                  // Wrap(
                  //   alignment: WrapAlignment.center,
                  //   children: [
                  //     Row(
                  //       mainAxisSize: MainAxisSize.min,
                  //       children: [
                  //         RadioMenuButton(
                  //           value: AppTheme.system,
                  //           groupValue: prefs.theme,
                  //           onChanged: (val) => prefs.theme = val!,
                  //           child: Text("System (${deviceInDarkMode ?? true ? "Dunkel" : "Hell"})"),
                  //         ),
                  //       ],
                  //     ),
                  //     Transform.translate(
                  //       offset: const Offset(0, -5),
                  //       child: Row(
                  //         mainAxisSize: MainAxisSize.min,
                  //         children: [
                  //           RadioMenuButton(
                  //             value: AppTheme.light,
                  //             groupValue: prefs.theme,
                  //             onChanged: (val) => prefs.theme = val!,
                  //             child: const Text("Hell"),
                  //           ),
                  //           RadioMenuButton(
                  //             value: AppTheme.dark,
                  //             groupValue: prefs.theme,
                  //             onChanged: (val) => prefs.theme = val!,
                  //             child: const Text("Dunkel"),
                  //           ),
                  //         ],
                  //       ),
                  //     ),
                  //   ],
                  // ),
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Los geht's!"),
                          Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.arrow_forward),
                          ),
                        ],
                      ),
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

snack(String text, {required bool error}) => SnackBar(
  content: Consumer<Preferences>(
    builder: (context, prefs, _) => Text(
      text,
      style: (error)
          ? TextStyle(
              color: (prefs.darkTheme) ? Colors.red[400] : Colors.red[600],
            )
          : null,
    ),
  ),
);

class LernSaxScreenMain extends StatefulWidget {
  const LernSaxScreenMain({super.key});

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
            child: Text("Bitte ${sie ? "melden Sie sich" : "melde Dich"} mit ${sie ? "Ihrem" : "Deinem"} JKG-LernSax-Konto an. Damit können wir bestätigen, dass ${sie ? "Sie" : "Du"} wirklich Teil unserer Schule ${sie ? "sind" : "bist"}."),
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
                  final msgr = ScaffoldMessenger.of(context);
                  msgr.clearSnackBars();
                  if (error == null) {
                    try {
                      registerApp(mail, pw).then((token) {
                        final credStore = Provider.of<CredentialStore>(context, listen: false);
                        credStore.lernSaxLogin = mail;
                        credStore.lernSaxToken = token;
                        if (parentTypeEndings.any((element) => mail.split("@")[0].endsWith(".$element"))) {
                          Provider.of<AppState>(context, listen: false).userType = UserType.parent;
                        }
                        msgr.showSnackBar(snack("Erfolgreich eingeloggt und verbunden.", error: false));
                        infoScreenState.next();
                      });
                    } catch (_) {
                      msgr.clearSnackBars();
                      msgr.showSnackBar(snack("Fehler beim Verbinden der App. Bitte ${sie ? "versuchen Sie" : "versuche"} es später erneut.", error: true));
                    }
                  } else {
                    msgr.showSnackBar(snack(error, error: true));
                  }
                });
              },
              child: const Text("Einloggen"),
            ),
          ),
          RichText(
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
                        TextSpan(text: "Wirklich ohne Anmeldung fortfahren? ${sie ? "Sie stimmen" : "Du stimmst"} damit der Datenschutzerklärung zu.")
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
                  Provider.of<AppState>(context, listen: false).clearInfoScreen();
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
    final check = await isMemberOfJKG(mail, pw);
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
      RegExp regex = RegExp(r"^[a-z]*(?:.(?:" + parentTypeEndings.join("|") + r"))?@jkgc\.lernsax\.de$", multiLine: true, caseSensitive: false);
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

/* TODO: skip this screen in favor of getting the data from some kinda LernSax groups for students and teachers for this app
/ maybe one group, but take advantage of the fact that only teachers can download from Upload-only folders to save the teacher plan login data there
/ or maybe be able to enable files for the institution and create a folder accessible for all logged in users, with one specifically for teachers */
class StuPlanScreenMain extends StatefulWidget {
  const StuPlanScreenMain({super.key});

  @override
  State<StuPlanScreenMain> createState() => _StuPlanScreenMainState();
}

class _StuPlanScreenMainState extends State<StuPlanScreenMain> {
  late TextEditingController _userController;
  String? _userErr;
  late TextEditingController _pwController;
  String? _pwErr;

  bool _triedToEnter = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) => Selector<Preferences, bool>(
        selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
        builder: (context, sie, _) => Column(
          children: [
            Text("Bitte ${sie ? "geben Sie" : "gebe"} die Anmeldedaten für ${sie ? "Ihren" : "Deinen"} Stundenplan auf plan.kepler-chemnitz.de ein."),
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
                        final mgr = ScaffoldMessenger.of(context);
                        if (error != null) {
                          mgr.clearSnackBars();
                          mgr.showSnackBar(snack(error, error: true));
                        } else {
                          final cs = Provider.of<CredentialStore>(context, listen: false);
                          cs.vpUser = username;
                          cs.vpPassword = password;
                          determineUserType(cs.lernSaxLogin, username, password)
                            .then((userType) {
                              Provider.of<AppState>(context, listen: false).userType = userType;
                              Provider.of<InternalState>(context, listen: false).lastUserType = userType;
                              mgr.clearSnackBars();
                              mgr.showSnackBar(snack("Erfolgreich angemeldet.", error: false));
                              infoScreenState.next();
                            });
                        }
                      });
                },
                child: const Text("Anmelden"),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_loading) const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Meldet an..."),
            ),
          ],
        ),
      ),
    );
  }

  String? checkUser() => (_userController.text.trim() == "") ? "Benutzername erforderlich." : null;
  String? checkPW() => (_pwController.text.trim() == "") ? "Passwort erforderlich." : null;

  Future<String?> handleLogin(String username, String password, bool sie) async {
    try {
      setState(() => _loading = true);
      final lres = await authRequest(lUrlMLeXmlUrl, username, password);
      if (lres.statusCode == 401) { // if teacher auth failed, try again with pupil auth
        final sres = await authRequest(sUrlMKlXmlUrl, username, password);
        if (sres.statusCode == 401) return "Ungültige Anmeldedaten.";
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

    super.initState();
  }

  @override
  void dispose() {
    _userController.dispose();
    _pwController.dispose();
    super.dispose();
  }
}
