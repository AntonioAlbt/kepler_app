import 'package:flutter/material.dart';
import 'package:kepler_app/info_screen.dart';

import 'package:kepler_app/libs/preferences.dart';
import 'package:provider/provider.dart';

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
                  const Text("Dies kann später in den Einstellungen geändert werden.", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
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
      }
    );
  }
}

class LernSaxScreenMain extends StatefulWidget {
  final InfoScreenDisplayController displayController;

  const LernSaxScreenMain({super.key, required this.displayController});

  @override
  State<LernSaxScreenMain> createState() => _LernSaxScreenMainState();
}

class _LernSaxScreenMainState extends State<LernSaxScreenMain> {
  late TextEditingController _mailController;
  String? _mailError;
  late TextEditingController _pwController;
  String? _pwError;

  bool triedToEnter = false;

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }

  @override
  void initState() {
    _mailController = TextEditingController();
    _mailController.addListener(() {
      if (_mailController.text.trim() == "" && triedToEnter) {
        setState(() => _mailError = "Keine E-Mail-Adresse angegeben!");
      } else if (!_mailController.text.endsWith("@jkgc.lernsax.de") && triedToEnter) {
        setState(() => _mailError = "Ungültige E-Mail-Adresse!");
      }
    });

    _pwController = TextEditingController();
    _pwController.addListener(() {
      if (_pwController.text.trim() == "" && triedToEnter) {
        setState(() => _pwError = "Kein Passwort angegeben!");
      }
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
