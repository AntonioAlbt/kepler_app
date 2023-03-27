## Interessantes an der App

Soll zur Organisation meiner BeLL-Arbeit dienen.
Zu jedem dieser Punkte gibt es noch mehr Notizen weiter unten.

- [Designing](#designing)
- [Navigationssystem](#navigationssystem)
- [Essensplan](#essensplan)
- [Kepler-News-System](#kepler-news-system)
- [Anmeldedaten-Speicherung](#anmeldedaten-speicherung)
- [Startseite](#startseite)

Noch zu erledigen:

- [Kepler-Stundenplan](#kepler-stundenplan)
- [LernSax](#lernsax)
- [FFJKG](#ffjkg)
- [Einstellungen](#einstellungen)

### Designing

- Flutter unterstüzt Material 3! → sieht modern aus, erfordert keine weitere Arbeit
- MaterialApp Design hat [`useMaterial3: true`](https://github.com/Gamer153/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/main.dart#L66)

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
- News auch offline (und später auf Homepage) anzeigen:
  - News-Data in Cache als JSON (siehe [NewsEntryData](https://github.com/Gamer153/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/tabs/news/news_data.dart#L7))
  - [`NewsEntries`](https://github.com/Gamer153/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/tabs/news/news.dart#L49-L50) werden daraus generiert
  - Offline-Anzeige von News nicht möglich, da echter Inhalt (HTML) nicht gecached werden kann
- **Benachrichtigungen:**
  - `Workmanager` zum Erstellen eines Tasks verwenden
  - damit wird alle 2 Stunden auf neue News überprüft
  - falls neue News verfügbar: Benachrichtigung wird gesendet (siehe [`sendNotification`](https://github.com/Gamer153/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/libs/tasks.dart#L57-L65) in `tasks.dart`, verwendet API von [`notifications.dart`](https://github.com/Gamer153/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/libs/notifications.dart))

### Kepler-Stundenplan

*TODO*

### Anmeldedaten-Speicherung

- Anmeldedaten sollen bei jedem Start der App überprüft werden
- Stundenplan-Auth-Daten sind vorgespeichert, aber sollen änderbar sein
- aus LernSax-Daten soll "Rolle" abgeleitet werden, die z.B. zum Lehrer-StuPlan berechtigt
- wenn kein Internet: Rolle als verifiziert ansehen, aber zur Änderung ist Internet nötig

### LernSax

*TODO*

### Startseite

- aus jedem wichtigen Tab wird ein "Widget" zur Startseite hinzugefügt
- Reihenfolge und Sichtbarkeit soll anpassbar sein

### FFJKG

- Unterstützung?

### Einstellungen

*TODO*

### Optional: Benarichtigungen

*TODO?*
