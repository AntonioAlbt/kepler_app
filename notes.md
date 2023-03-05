## Interessantes an der App
Soll zur Organisation meiner BeLL-Arbeit dienen.
Zu jedem dieser Punkte gibt es noch mehr Notizen weiter unten.

- [Designing](#designing)
- [Navigationssystem](#navigationssystem)
- [Kepler-News-System](#kepler-news-system)
- 

### Designing
- Flutter unterstüzt Material 3! → sieht modern aus, erfordert keine weitere Arbeit
- MaterialApp Design hat `useMaterial3: true` ([hier](https://github.com/Gamer153/kepler_app/blob/main/lib/main.dart#L29))

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
