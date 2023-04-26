## Interessantes an der App

Soll zur Organisation meiner BeLL-Arbeit dienen.
Zu jedem dieser Punkte gibt es noch mehr Notizen weiter unten.

- [Designing](#designing)
- [Navigationssystem](#navigationssystem)
- [Essensplan](#essensplan)
- [Kepler-News-System](#kepler-news-system)
- [Daten-Speicherung](#daten-speicherung)
- [Startseite](#startseite)
- [Benachrichtigungen](#benarichtigungen)
- [Kepler-Stundenplan](#kepler-stundenplan)
- [LernSax](#lernsax)

Noch zu erledigen:

- [FFJKG](#ffjkg)
- [Einstellungen](#einstellungen)

### Designing

- Flutter unterstüzt Material 3! → sieht modern aus, erfordert keine weitere Arbeit
- MaterialApp Design hat [`useMaterial3: true`](https://github.com/Gamer153/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/main.dart#L66)
- Drawer-Items ähnlich zu Material 3-`NavigationDrawer` gestaltet
  - gute Übersichtlichkeit
  - angenehme Farben und Größe
  - auch Meinungen von Freunden und Familie eingeholt

### Navigationssystem

- ursprüngliche Entscheidung: Material3 NavigationDrawers
  - aber: Items nehmen sehr viel Platz weg
  - CustomDesign nicht (einfach) möglich?
  - Verschachtelung von Drawer-Items nicht möglich
- größtes Problem:
  - viele nötige Elemente, meine beste Lösungsidee: **verschachtelte Drawer-Items**
  - allerdings: keine gute Implementation dafür gefunden?
- Lösung:
  - also eigenes System dafür entwickelt, erlaubt komplette Bearbeitbarkeit (siehe [`drawer.dart`](https://github.com/Gamer153/kepler_app/blob/main/lib/drawer.dart))
  - Design ähnlich wie Mat3 NavDrawers, aber kompakter und mit Möglichkeit für `children`

### Essensplan

- eigentlich: Bestellung und Abfrage per API direkt integrieren
- aber: DLS erlaubte mir das (auf Anfrage) nicht
- deshalb: Webseite-Link und Knopf, um die App zu installieren oder öffnen

### Kepler-News-System

- kepler-chemnitz.de Wordpress-Post-API ist gesperrt ([`kepler-chemnitz.de/wp-json/wp/v2/posts`](https://kepler-chemnitz.de/wp-json/wp/v2/posts))
- deshalb verwende ich den RSS/Atom-Feed (auf [`kepler-chemnitz.de/?feed=atom`](https://kepler-chemnitz.de/?feed=atom) zu finden, paginated mit URL-Argument paged), um die Posts zu erfassen
- für genauere Ansichten des Artikels:
  - öffnet echte Post-URL in Custom WebView
  - Footer/Header werden durch JS entfernt
- *TODO: wenn möglich, Zugriff auf die API bekommen, um Posts besser anzuzeigen* (eher nicht, da Einbettung in die App die Sperre unnötig machen würde)
- News auch offline anzeigen:
  - News-Data in Cache als JSON (siehe [NewsEntryData](https://github.com/Gamer153/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/tabs/news/news_data.dart#L7))
  - [`NewsEntries`](https://github.com/Gamer153/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/tabs/news/news.dart#L49-L50) werden daraus generiert
  - Offline-Anzeige von News nicht möglich, da echter Inhalt (HTML) nicht gecached werden kann
- siehe [Benachrichtigungen](#benarichtigungen)
- News-"Widget" zur Homepage hinzugefügt
  - App lädt neue News beim Öffnen der App
  - neueste 3 News sichtbar auf App-Homepage

### Kepler-Stundenplan

- Anmeldedaten werden bei Anmeldung übergeben
- Schülerplan:
  - Klassen-/Kursauswahl, die auf Hauptseite anzuzeigen sind
  - Freie Zimmer, aber diesmal in gut (shots fired to StuPlanLive xD)
  - Klassenpläne, alle Vertretungen
  - vielleicht noch Daten zu abwesenden Lehrern?
- Lehrerplan:
  - keine Klassen-/Kurswahl, da jeder Lehrer eigenen Plan hat
  - auch Zugriff auf freie Zimmer
  - zusätzlich zu Klassenplänen noch Lehrerpläne
- wie Navigation zwischen Tagen?

### Daten-Speicherung

- Datenschutz:
  - sollte kein Problem sein
  - da *keine neuen Server* benötigt werden sollen -> keine neue Datenspeicherung
  - Anmeldedaten werden nur lokal in der App gespeichert
- Anmeldedaten sollen bei jedem Start der App überprüft werden
- Stundenplan-Auth-Daten für Schüler sind vorgespeichert, aber sollen änderbar sein
- Rolle bestimmen:
  - Anmeldungsablauf:
    1. Mit LernSax anmelden
    2. Zugehörigkeit zu Johannes-Kepler-Gymnasium prüfen
    3. Wenn LernSax-Mail auf .eltern, .vati, .mutti, .tante oder .grosseltern endet: **Eltern**
    4. Mit Stundenplan-Daten anmelden
    5. Wenn Daten Zugriff auf Lehrerplan geben: **Lehrer**
    6. Wenn Daten Zugriff auf Schülerplan geben: **Schüler**
  - damit werden Rollen bestimmt
  - Problem: Stundenplan-Anmeldedaten werden nicht ungültig
  - Lösung: da LernSax-Anmeldung auch überprüft wird, werden diese dann zur Überprüfung verwendet
- wenn kein Internet: Rolle als verifiziert ansehen, aber zur Änderung ist Internet nötig

### LernSax

- API-Dokumentation ist öffentlich (siehe [lernsax.de/wws/api.php](https://www.lernsax.de/wws/api.php))
  - Antworten sind komplett undokumentiert
  - Art der Anfrage ist komplett undokumentiert
  - keine Beispiele
  - nach Anfrage: erklärende PDF erhalten -> JSON-RPC-Schnittstelle (`https://www.lernsax.de/jsonrpc.php` (`www.` ist wichtig!))
- Anmeldung:
  - API-Methode `login` verwenden
  - dann neue Anwendung registrieren
  - Schlüssel davon speichern
  - damit wird nicht das Passwort gespeichert, sondern nur der Anwendungs-Anmelde-Schlüssel
  - Sicherheit ist damit gewährleistet.
- Verwendung:
  - Tasks in der App einsichtbar machen
  - Übersicht für Mails hinzufügen
  - wenn möglich: Übersicht für neue Dateien hinzufügen
  - für andere Funktionen, wie Dateien: auf LernSax-Messenger App verlinken

### Startseite

- aus jedem wichtigen Tab wird ein "Widget" zur Startseite hinzugefügt
- Reihenfolge und Sichtbarkeit soll anpassbar sein

### FFJKG

- Unterstützung?

### Einstellungen

*TODO*

### Benarichtigungen

- für News:
  - bevorzugt hätte ich Firebase-Push-Notifications verwendet - aber: das erfordert Integration mit WordPress (und erfordert Firebase-Projekt -> Datenschutz-Frage)
  - `Workmanager` zum Erstellen eines Tasks verwenden
  - damit wird alle 2 Stunden auf neue News überprüft
  - falls neue News verfügbar: Benachrichtigung wird gesendet (siehe [`sendNotification`](https://github.com/Gamer153/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/libs/tasks.dart#L57-L65) in `tasks.dart`, verwendet API von [`notifications.dart`](https://github.com/Gamer153/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/libs/notifications.dart))

### realistische? Erwartungen

- ich glaube halt einfach mal nicht, dass je ein Lehrer oder Elternteil die App verwenden wird
- aber der Gedanke zählt xD
