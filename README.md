# Die Kepler-App

Hi! Dieses Repo enthält den kompletten Quellcode für die Kepler-App, die Übersichts-App für Schüler des JKGs.

Notizen von mir zu dem interessanten Zeug (Code) findest du [hier](notes.md).

## Build-Varianten

Durch Build-Konstanten können verschiedene Varianten der App gebaut werden. Dabei gibt es diese Konstanten:

- `beta` = ist Build eine Beta-Version (Standard: `false`)
  - falls `sentry_enabled`, wird Sentry für Entwicklerzwecke zwingend aktiviert (Standard: `false`)
  - Schrift "BETA-VERSION" wird auf Ladebildschirm angezeigt
- `sentry_enabled` = ist Sentry verfügbar (nimmt an, dass `sentryDSN` in `libs/sentry_dsn.dart` gültig ist!)
  - wenn aktiviert, werden Daten an Sentry übermittelt
  - Einstellung zu Sentry wird verfügbar und Hinweis/InfoScreen wird angezeigt
- `debug_features` = sollen Debug-Features aktiv und sichtbar sein (Standard: `kDebugMode`)
  - freies Skippen durch InfoScreens
  - Intro neu zeigen vom Home -> NavBar Action
  - Debug-Knöpfe im Home (ändern sich manchmal)
  - zeigt Herkunft bei Stundenplan-Daten an
  - zeigt LS class login bei Tasks an
  - zeigt Testdaten bei Serverproblemen beim Pendel an
  - ist automatisch bei Debug-Variante von App aktiviert
- `debug_notif_data` = sollen Testdaten für Benachrichtungen angezeigt werden (Standard: `false`)
  - fügt jedes Mal beim Ausführen des Hintergrund-Tasks Testdaten an
  - zeigt damit jedes Mal zwei Benachrichtigungen (Stundenplan-Änderungen und neue News) an

Zum Aktivieren beim App-Build `--dart-define=<varname>=[true|false]` an `flutter run` oder `flutter build` übergeben, z.B.:

- `flutter build apk --dart-define=beta=true --dart-define=sentry_enabled=true`
- `flutter build apk --dart-define=debug_features=true`

Wenn ein ungültiger Wert übergeben wird, wird der Standardwert genommen.
