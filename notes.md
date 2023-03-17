## Interessantes an der App
Soll zur Organisation meiner BeLL-Arbeit dienen.
Zu jedem dieser Punkte gibt es noch mehr Notizen weiter unten.

- [Designing](#designing)
- [Navigationssystem](#navigationssystem)
- [Essensplan](#essensplan)
- [Kepler-News-System](#kepler-news-system)

Noch zu erledigen:
- [Kepler-Stundenplan](#kepler-stundenplan)
- [Anmeldedaten-Speicherung](#anmeldedaten-speicherung)
- [LernSax](#lernsax)
- [Startseite](#startseite)
- [FFJKG](#ffjkg)
- [Einstellungen](#einstellungen)
- [Optional: Benarichtigungen](#optional-benarichtigungen)

### Designing
- Flutter unterstüzt Material 3! → sieht modern aus, erfordert keine weitere Arbeit
- MaterialApp Design hat `useMaterial3: true` ([hier](https://github.com/Gamer153/kepler_app/blob/8acdc46709d750b3c2f337eda64e79e1c63ff7cd/lib/main.dart#L29))

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

### Kepler-News-System
- kepler-chemnitz.de Wordpress-Post-API ist gesperrt (wäre [hier](https://kepler-chemnitz.de/wp-json/wp/v2/posts) zu finden)
- deshalb verwende ich den RSS/Atom-Feed ([hier](https://kepler-chemnitz.de/?feed=atom) zu finden, paginated mit URL-Argument paged), um die Posts zu erfassen
- für genauere Ansichten des Artikels:
    - öffnet echte Post-URL in Custom WebView
    - Footer/Header werden durch JS entfernt
- *TODO: wenn möglich, Zugriff auf die API bekommen, um Posts besser anzuzeigen*
- News auch offline (und später auf Homepage) anzeigen:
  - News-Data in Cache als JSON (siehe [NewsEntryData](https://github.com/Gamer153/kepler_app/blob/8acdc46709d750b3c2f337eda64e79e1c63ff7cd/lib/tabs/news.dart#L30))
  - [`NewsEntries`](https://github.com/Gamer153/kepler_app/blob/8acdc46709d750b3c2f337eda64e79e1c63ff7cd/lib/tabs/news.dart#L48) werden daraus generiert
  - Offline-Anzeige von News nicht möglich, da echter Inhalt (HTML) nicht gecached werden kann

### Kepler-Stundenplan
*TODO*

### Anmeldedaten-Speicherung
*TODO*

### LernSax
*TODO*

### Startseite
*TODO*

### FFJKG
- Unterstützung?

### Einstellungen
*TODO*

### Optional: Benarichtigungen
*TODO?*
