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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/notifications.dart';

import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/tabs/about.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// verschiedene Sammlungen von InfoScreens für verschiedene Verwendungen - siehe Namen
final introScreens = [welcomeScreen, lernSaxLoginScreen, stuPlanLoginScreen, notificationInfoScreen, finishScreen];
final loginAgainScreens = [lernSaxLoginAgainScreen(true), stuPlanLoginAgainScreen, finishScreen];
final loginAgainScreensUncloseable = [lernSaxLoginAgainScreen(false), stuPlanLoginAgainScreen, finishScreen];

/// viele InfoScreens haben statt nur Text beim InfoText ein komplettes eigenes Widget
/// -> da häufig State benötigt wird, hier z.B. für die Anrede-Auswahl
const welcomeScreen = InfoScreen(
  infoTitle: Text("Willkommen in der Kepler-App!"),
  infoText: WelcomeScreenMain(),
  closeable: false,
  infoImage: Text("🎉", style: TextStyle(fontSize: 48)),
);

/// da LernSaxScreenMain inzwischen auch andere Verwendungen zulässt und die Anmeldung nicht mehr
/// komplett selbst verarbeitet und vor allem nicht mehr selbst speichert, wird dies für das Intro hier erledigt
void lernSaxLoginScreenMainProcessing(String mail, String token, BuildContext context) {
  final credStore = Provider.of<CredentialStore>(context, listen: false);
  credStore.lernSaxLogin = mail;
  credStore.lernSaxToken = token;
  if (parentTypeEndings.any((element) => mail.split("@")[0].endsWith(".$element"))) {
    Provider.of<AppState>(context, listen: false).userType = UserType.parent;
  }
  showSnackBar(text: "Erfolgreich eingeloggt und verbunden.", clear: true);

  Provider.of<LernSaxData>(context, listen: false).clearData();

  infoScreenState.next();
}

/// ähnlich wie für lslsmProcessing, nur wenn "Ich habe keine Anmeldedaten." ausgewählt wurde
void lernSaxLoginScreenMainNonLogin(BuildContext context) {
  Provider.of<InternalState>(context, listen: false)
    ..introShown = true
    ..lastUserType = UserType.nobody;
  Provider.of<AppState>(context, listen: false)
    ..userType = UserType.nobody
    ..clearInfoScreen();
}

const lernSaxLoginScreen = InfoScreen(
  infoTitle: Text("LernSax-Anmeldung"),
  infoText: LernSaxScreenMain(
    onRegistered: lernSaxLoginScreenMainProcessing,
    onNonLogin: lernSaxLoginScreenMainNonLogin,
  ),
  closeable: false,
  infoImage: Icon(Icons.laptop, size: 48),
);

// Variante des LernSax-LoginScreens für erneute Anmeldung
InfoScreen lernSaxLoginAgainScreen(bool closeable) => InfoScreen(
  infoTitle: const Text("LernSax-Anmeldung"),
  infoText: const LernSaxScreenMain(
    again: true,
    onRegistered: lernSaxLoginScreenMainProcessing,
    onNonLogin: lernSaxLoginScreenMainNonLogin,
  ),
  closeable: closeable,
  infoImage: const Icon(Icons.laptop, size: 48),
);

const stuPlanLoginScreen = InfoScreen(
  infoTitle: Text("Stundenplan-Anmeldung"),
  infoText: StuPlanScreenMain(),
  closeable: false,
  infoImage: Icon(Icons.list_alt, size: 48),
);

// Variante des StuPlan-LoginScreens für erneute Anmeldung
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

/// da dieser Screen keinen State benötigt (da z.B. keine Auswahl bereitgestellt wird), hat er kein eigenes Widget,
/// und alles, was angezeigt wird, ist direkt mit hier
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
            /// wie an den englischen Kommentaren erkennbar, sind manche Zweige dieses Switch-es unnötig und können
            /// nicht erreicht werden - Dart mag es aber, wenn man bei Enums jede Möglichkeit beachtet (glaube ich???)
            /// - ich habe hier nicht alle Varianten in einen String integriert, weil es sonst sehr unübersichtlich
            ///   geworden wäre, stattdessen ist es also mit einem Switch geregelt
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
                /// aber er hat nie nachgeschaut... :'(
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
  /// diesen Screen kann man auch selbst schließen (durch Drücken vom x oben rechts oder
  /// Durchführen von "Zurück" (nur Android))
  /// (macht halt keinen Unterschied zu wenn man einfach den "Schließen"-Knopf drückt)
  onTryClose: (_, context) {
    Provider.of<InternalState>(context, listen: false).introShown = true;
    return true;
  },
  closeable: true,
);

/// wichtigste und erste Frage beim Öffnen der App wird hier abgefragt: soll der Benutzer mit Du oder Sie angeredet
/// werden? -> absichtlich unabhängig vom Benutzertyp, um, falls gewünscht, nur respektvoll mit Sie anzureden
/// -> oder eben auch bei Lehrern mit Du, falls gewünscht
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
            /// Erster Text, den der Benutzer sieht! -> Immer beachten, dass jeder Text der App die Anredewahl
            /// beachten muss! (meist mit einem Selector<bool, Preferences> gemacht, wenn nur preferredPronoun
            /// aus Preferences benötigt wird, siehe woanders lol)
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
                      /// dadurch, dass der Wert direkt in den Preferences geändert wird, wird der Text auf dieser
                      /// Seite automatisch live mit Treffen der Auswahl aktualisiert -> Benutzer weiß direkt,
                      /// was die Einstellung beeinflusst
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
  /// wird der Screen in einem "Erneut einloggen"-Zusammenhang verwendet (entsprechende Formulierungen verwenden)
  final bool again;
  /// wird nach erfolgreicher Registrierung der App auf dem LernSax-Konto aufgerufen
  final void Function(String mail, String token, BuildContext context) onRegistered;
  /// ob der Knopf "Ich habe keine Anmeldedaten." angezeigt werden soll
  final bool allowNotLogin;
  /// ob ein Benutzer ohne Anmeldung gefragt werden soll, ob er bei neuen News benachrichtigt werden will
  final bool askNotLoginForNotifications;
  /// wird aufgerufen, wenn ein Benutzer keine Anmeldedaten hat
  final void Function(BuildContext context) onNonLogin;
  /// ob extra Abstand nach unten hinzugefügt werden soll (für Anzeige auf InfoScreens)
  final bool extraPadding;
  /// wird der Screen in einem "Account hinzufügen"-Zusammenhang verwendet
  final bool additionalAccount;

  const LernSaxScreenMain({
    super.key,
    this.again = false,
    required this.onRegistered,
    this.allowNotLogin = true,
    this.askNotLoginForNotifications = true,
    required this.onNonLogin,
    this.extraPadding = true,
    this.additionalAccount = false,
  });

  @override
  State<LernSaxScreenMain> createState() => _LernSaxScreenMainState();
}

const lernSaxAGBLink = "https://www.lernsax.de/wws/1491042.php";
const lernSaxDSELink = "https://www.lernsax.de/wws/1494114.php";
class _LernSaxScreenMainState extends State<LernSaxScreenMain> {
  late TextEditingController _mailController;
  String? _mailError;
  late TextEditingController _pwController;
  String? _pwError;

  /// Fehler erst anzeigen, nachdem der Benutzer einmal auf "Einloggen" getippt hat
  /// - sonst werden schon vor oder während des Eingebens immer Fehler angezeigt
  bool _triedToEnter = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    const TextStyle link = TextStyle(color: Colors.blue, decoration: TextDecoration.underline);
    final sie = Provider.of<Preferences>(globalScaffoldContext, listen: false).preferredPronoun == Pronoun.sie;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            (widget.additionalAccount) ?
            "${sie ? "Sie können sich" : "Du kannst dich"} hier mit einem weiteren JKG-LernSax-Konto anmelden."
            : (widget.again) ?
            "Bitte ${sie ? "melden Sie sich" : "melde Dich"} erneut mit ${sie ? "Ihrem" : "Deinem"} JKG-LernSax-Konto an."
            :
            "Bitte ${sie ? "melden Sie sich" : "melde Dich"} mit ${sie ? "Ihrem" : "Deinem"} JKG-LernSax-Konto an. Damit können wir bestätigen, dass ${sie ? "Sie" : "Du"} wirklich Teil unserer Schule ${sie ? "sind" : "bist"}.",
          ),
        ),
        TextField(
          controller: _mailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: "LernSax-Email-Adresse",
            errorText: _mailError,
          ),
        ),
        TextField(
          controller: _pwController,
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          obscureText: true,
          decoration: InputDecoration(
            labelText: "LernSax-Passwort",
            errorText: _pwError,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 12, bottom: widget.extraPadding ? 16 : 0),
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
              // close the keyboard when tapping the button
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
                      if (!mounted) return;
                      widget.onRegistered(mail, token, this.context);
                    });
                  } catch (e, s) {
                    logCatch("ls-intro", e, s);
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
        // don't show this again because the user already agreed - set to true when re-logging
        if (!widget.again) RichText(
          textAlign: TextAlign.center,
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
                  ..onTap = () => launchUrl(Uri.parse(keplerAppDSELink), mode: LaunchMode.externalApplication),
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
                text: " und der "
              ),
              TextSpan(
                text: "Datenschutzerklärung",
                style: link,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => launchUrl(
                    Uri.parse(lernSaxDSELink),
                    mode: LaunchMode.externalApplication,
                  ),
              ),
              const TextSpan(
                text: " von LernSax zu. Hinweis: Diese App ist in keiner Weise mit LernSax, WebWeaver, DigiOnline GmbH oder dem Freistaat Sachsen assoziiert.",
              ),
            ],
          ),
        ),
        if (widget.allowNotLogin) TextButton(
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
                if (!context.mounted) return;
                widget.onNonLogin(context);
                if (!widget.again && widget.askNotLoginForNotifications) {
                  if (!globalScaffoldContext.mounted) return;
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
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                return;
                              }
                              try {
                                requestNotificationPermission().then((val) {
                                  if (val) {
                                    showSnackBar(textGen: (sie) => "Danke für ${sie ? "Ihre" : "Deine"} Zustimmung!");
                                  }
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                });
                              } catch (e, s) {
                                logCatch("ls-intro", e, s);
                                if (!context.mounted) return;
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
        if (widget.extraPadding) const Padding(padding: EdgeInsets.all(16)),
      ],
    );
  }

  /// überprüft, ob Login für die Kepler-App verwendet werden kann
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
      /// ursprünglich hatte ich hier mal mit einem RegEx die Mail überprüft, um ungültige Mails schon eher abzufangen
      /// - das hat aber nur für zu viele Benutzer gesorgt, die sich nicht anmelden konnten -_-
      /// -> ist jetzt alles weg, Hauptsache die Eingabe endet auf .lernsax.de (wird ja eh noch von LernSax bei der
      /// Anmeldung geprüft)

      // RegExp regex = RegExp(r"^[a-z]*[0-9]*(?:.(?:" + parentTypeEndings.join("|") + r"))?@[a-z0-9]+\.lernsax\.de$", multiLine: true, caseSensitive: false);
      // RegExp regex = RegExp(r"^[a-z0-9.]+@[a-z0-9]+\.lernsax\.de$", multiLine: true, caseSensitive: false);
      // if (!regex.hasMatch(_mailController.text)) return "Ungültige LernSax-E-Mail-Adresse.";
      if (!_mailController.text.endsWith(".lernsax.de")) return "Ungültige LernSax-E-Mail-Adresse.";
    }
    final creds = Provider.of<CredentialStore>(globalScaffoldContext, listen: false);
    if (widget.additionalAccount && _mailController.text != "" && (creds.alternativeLSLogins.contains(_mailController.text) || creds.lernSaxLogin == _mailController.text)) {
      return "Dieses LernSax-Konto ist bereits angemeldet.";
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
    /// immer wenn die Daten geändert werden, überprüfe auf Fehler / zeige an

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
  /// wird der Screen in einem "Erneut einloggen"-Zusammenhang verwendet (entsprechende Formulierungen verwenden)
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

  /// siehe LernSaxScreenMainState
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
                            if (!context.mounted) return;
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
                              if (!context.mounted) return;
                              final cs = Provider.of<CredentialStore>(context, listen: false);
                              cs.vpUser = username;
                              cs.vpPassword = password;
                              determineUserType(cs.lernSaxLogin!, cs.lernSaxToken!)
                                .then((userType) {
                                  if (!context.mounted) return;
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

  /// komprimierte Funktionen zum Überprüfen der Eingaben, da nur auf "nicht leer" geprüft werden muss
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
    } catch (e, s) {
      logCatch("sp-intro", e, s);
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

    /// für die App sind auf LernSax, wie in /lernsax_data/info.md beschrieben, die Login-Daten für Schüler/Lehrer
    /// gespeichert - diese werden hier abgefragt, ihre Gültigkeit überprüft, und wenn alles funktioniert,
    /// der Benutzer einfach darauf hingewiesen (und er kann direkt fortfahren)
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
    if (creds.lernSaxLogin == lernSaxDemoModeMail) return true;
    // ignore the online bool because it doesn't matter - I don't show any actual error message to the user
    final (_, teacher) = await isTeacher(creds.lernSaxLogin!, creds.lernSaxToken!);
    if (teacher == null) return null;
    final (_, data) = await getLernSaxAppDataJson(creds.lernSaxLogin!, creds.lernSaxToken!, teacher);
    if (data == null || data.isTeacherData != teacher) return null;

    try {
      final lres = await authRequest(Uri.parse("${data.host}$lUrlMLeXmlPath"), data.user, data.password);
      if (lres!.statusCode != 200) throw Exception("no");
      return true;
    } catch (e, s) {
      if (!e.toString().endsWith(" no")) logCatch("ls-intro", e, s);
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
                        if (prefs.enabledNotifs.isEmpty) {
                          infoScreenState.next();
                          return;
                        }
                        checkNotificationPermission().then((hasAgreed) {
                          if (!hasAgreed) {
                            requestNotificationPermission().then((agreedNow) {
                              if (agreedNow) {
                                showSnackBar(text: "Danke für ${sie ? "Ihre" : "Deine"} Zustimmung.", error: false);
                              } else {
                                prefs.enabledNotifs = [];
                                showSnackBar(text: "Leider ${sie ? "haben Sie" : "hast Du"} nicht zugestimmt. Wir werden keine Benachrichtigungen senden. ${sie ? "Sie können" : "Du kannst"} sie in den Einstellungen aktivieren.", error: true);
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
