import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/lernsax.dart';

import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/privacy_policy.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
                          )
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
      builder: (context, mitSie, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text("Bitte ${mitSie ? "melden Sie sich" : "melde Dich"} mit ${mitSie ? "Ihrem" : "Deinem"} JKG-LernSax-Konto an. Damit können wir bestätigen, dass ${mitSie ? "Sie" : "Du"} wirklich Teil unserer Schule ${mitSie ? "sind" : "bist"}."),
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
                snack(String text, {required bool error}) => SnackBar(
                  content: Consumer<Preferences>(
                    builder: (context, prefs, _) => Text(
                      text,
                      style: (error) ? TextStyle(
                        color: (prefs.darkTheme)
                              ? Colors.red[400]
                              : Colors.red[600],
                      ) : null,
                    ),
                  ),
                );
                runLogin(mail, pw).then((error) {
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
                      msgr.showSnackBar(snack("Fehler beim Verbinden der App. Bitte ${mitSie ? "versuchen Sie" : "versuche"} es später erneut.", error: true));
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
                  text: "Mit dem Fortfahren ${mitSie ? "stimmen Sie" : "stimmst du"} den ",
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
                  title: Text("${mitSie ? "Sind Sie" : "Bist du"} sicher?"),
                  content: Text("Wenn ${mitSie ? "Sie sich" : "du dich"} nicht ${mitSie ? "anmelden, können Sie" : "anmeldest, kannst du"} auf die meisten Funktionen der App nicht zugreifen. Dies ist vor allem für interessierte Eltern ohne LernSax-Zugang geeignet. Wirklich ohne Anmeldung fortfahren?"),
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

  Future<String?> runLogin(String mail, String pw) async {
    setState(() => _loading = true);
    final check = await isMemberOfJKG(mail, pw);
    setState(() => _loading = false);
    switch (check) {
      case MOJKGResult.invalidLogin:
        return "Ungültige Anmeldedaten. Bitte überprüfe deine Eingabe.";
      case MOJKGResult.allGood:
        return null;
      case MOJKGResult.noJKGMember:
        return "Du bist kein Mitglied des JKGs.";
      case MOJKGResult.otherError:
      case MOJKGResult.invalidResponse:
        return "";
    }
  }

  String? checkMail() {
    if (_mailController.text.trim() == "" && _triedToEnter) {
      return "Keine E-Mail-Adresse angegeben!";
    } else if (!_mailController.text.endsWith("@jkgc.lernsax.de") &&
        _triedToEnter) {
      return "Ungültige E-Mail-Adresse!";
    }
    return null;
  }

  String? checkPW() {
    if (_pwController.text.trim() == "" && _triedToEnter) {
      return "Kein Passwort angegeben!";
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
