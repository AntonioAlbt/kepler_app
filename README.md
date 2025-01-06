# Die Kepler-App

## Verfügbar in Stores

<table>
  <tr>
    <td>
<a href='https://play.google.com/store/apps/details?id=de.keplerchemnitz.kepler_app'><img alt='Jetzt bei Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/de_badge_web_generic.png' height="75"/>
</a></td>
    <td>
<a href="https://apps.apple.com/de/app/kepler-app/id6499428205"><img src="https://upload.wikimedia.org/wikipedia/commons/thumb/3/3c/Download_on_the_App_Store_Badge.svg/640px-Download_on_the_App_Store_Badge.svg.png" height="56" />
</a></td>
    <td>
<a href="https://f-droid.org/packages/de.keplerchemnitz.kepler_app">
    <img src="https://fdroid.gitlab.io/artwork/badge/get-it-on-de.png"
    alt="Jetzt auf F-Droid"
    height="80">
</a></td>
  </tr>
  <tr>
    <td>
      <a href="https://play.google.com/store/apps/details?id=de.keplerchemnitz.kepler_app">Link: Android (Play Store)</a>
    </td>
    <td>
      <a href="https://apps.apple.com/de/app/kepler-app/id6499428205">Link: iOS (App Store)</a>
    </td>
    <td>
      <a href="https://f-droid.org/packages/de.keplerchemnitz.kepler_app">Link: Android (F-Droid)</a>
    </td>
  </tr>
</table>

Hinweis: Die Android-Veröffentlichungen werden mit zwei verschiedenen Zertifikaten bereitgestellt:

1. Google Play (im Play Store)
2. F-Droid (in F-Droid) und GitHub Releases

Beim Wechseln zwischen den Varianten muss die App immer deinstalliert werden, wobei alle Daten verloren gehen.

Wichtiger Hinweis für Veröffentlichung: nicht vergessen, `logup_host` zu setzen! Die Buildkonstante hat keinen Standardwert.

---

Hi! Dieses Repo enthält den kompletten Quellcode für die Kepler-App, die Übersichts-App für Schüler des JKGs.

Die Kepler-App ist lizensiert unter der GPLv3 (GNU Public License Version 3), siehe [LICENSE](LICENSE).

Hinweis zu Kommentaren im Code: Kommentare auf Englisch sind älter und nur vereinzeilt an wichtigen/lustigen Stellen verwendet, Kommentare auf Deutsch dienen der Erklärung der Funktionsweise von so vielen Elementen im Code wie möglich und sind auch meist detaillierter. Ich wollte aber die alten englischen Kommentare nicht löschen.

## Build-Konstanten

Durch Build-Konstanten können verschiedene Varianten der App gebaut und Werte gesetzt werden. Dabei gibt es diese Konstanten:

- `beta` = ist Build eine Beta-Version (Standard: `false`)
  - Schrift "BETA-VERSION" wird auf Ladebildschirm angezeigt
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
- `creds_debug` = sollen Debugausgaben zu Stundenplan-Anmeldedaten zum Log hinzugefügt werden (Standard: `false`)
- `logup_host` = Standardhost für LogUp (Standard: `null` → Log hochladen deaktiviert)

Zum Aktivieren beim App-Build `--dart-define=<varname>=[true|false]` an `flutter run` oder `flutter build` übergeben, z.B.:

- `flutter build apk --dart-define=beta=true`
  - &rarr; Android APK als Beta
- `flutter build ipa --dart-define=debug_features=true`
  - &rarr; Apple Build mit Debug Features aktiviert

Wenn ein ungültiger Wert übergeben wird, wird der Standardwert genommen.

<small>
Google Play und das Google Play-Logo sind Markenzeichen von Google LLC.
Apple und App Store sind Markenzeichen von Apple Inc.
</small>
