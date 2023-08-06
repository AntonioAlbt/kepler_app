import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/lernsax.dart';

import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/privacy_policy.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

welcomeScreen(InfoScreenDisplayController controller) => InfoScreen(
  infoTitle: const Text("Willkommen in der Kepler-App!"),
  infoText: WelcomeScreenMain(displayController: controller),
  closeable: false,
  infoImage: const Text("🎉", style: TextStyle(fontSize: 48)),
);

lernSaxLoginScreen(InfoScreenDisplayController controller) => InfoScreen(
  infoTitle: const Text("LernSax-Anmeldung"),
  infoText: LernSaxScreenMain(displayController: controller),
  closeable: false,
  infoImage: const Icon(Icons.laptop, size: 48),
);

stuPlanLoginScreen(InfoScreenDisplayController controller) => InfoScreen(
  infoTitle: const Text("Stundenplan-Anmeldung"),
  infoText: StuPlanScreenMain(displayController: controller),
  closeable: false,
  infoImage: const Icon(Icons.list_alt),
);

finishScreen(InfoScreenDisplayController controller) => InfoScreen(
  infoImage: const Icon(Icons.check_box),
  infoTitle: const Text("Danke und willkommen!"),
  infoText: Selector<Preferences, bool>(
    selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
    builder: (context, mitSie, _) {
      return Column(
        children: [
          Text("Vielen Dank für ${mitSie ? "Ihre" : "Deine"} Anmeldung. ${mitSie ? "Sie können" : "Du kannst"} jetzt auf alle Funktionen der App, wie den Stundenplan oder die Kepler-News zugreifen."),
          Consumer<AppState>(
            builder: (context, state, _) {
              return ElevatedButton(
                onPressed: () => state.clearInfoScreen(),
                child: const Text("Schließen"),
              );
            }
          ),
        ],
      );
    }
  ),
  closeable: true,
);

class WelcomeScreenMain extends StatefulWidget {
  final InfoScreenDisplayController displayController;

  const WelcomeScreenMain({super.key, required this.displayController});

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
                        widget.displayController.next();
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
  final InfoScreenDisplayController displayController;

  const LernSaxScreenMain({super.key, required this.displayController});

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
                        msgr.showSnackBar(snack("Erfolgreich eingeloggt und verbunden.", error: false));
                        widget.displayController.next();
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
      case MOJKGResult.invalidResponse:
        return "Es ist ein Fehler aufgetreten. Bitte ${sie ? "versuchen Sie" : "versuche"} es später erneut.";
    }
  }

  String? checkMail() {
    if (_mailController.text.trim() == "" && _triedToEnter) {
      return "Keine E-Mail-Adresse angegeben.";
    } else if (!_mailController.text.endsWith("@jkgc.lernsax.de") &&
        _triedToEnter) {
      return "Ungültige LernSax-E-Mail-Adresse.";
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
  final InfoScreenDisplayController displayController;

  const StuPlanScreenMain({super.key, required this.displayController});

  @override
  State<StuPlanScreenMain> createState() => _StuPlanScreenMainState();
}

class _StuPlanScreenMainState extends State<StuPlanScreenMain> {
  late TextEditingController _userController;
  String? _userErr;
  late TextEditingController _pwController;
  String? _pwErr;

  bool _triedToEnter = false;

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
                  handleLogin(_userController.text.trim(), _pwController.text);
                },
                child: const Text("Anmelden"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? checkUser() => (_userController.text.trim() == "") ? "Benutzername erforderlich." : null;
  String? checkPW() => (_pwController.text.trim() == "") ? "Passwort erforderlich." : null;

  Future<void> handleLogin(String username, String password) async {
    
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
