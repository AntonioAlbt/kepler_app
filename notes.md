# Hinweis

Diese Notizen sind nicht aktuell und größere Teile passen nicht mehr zum Quelltext. Sie sind als archiviert zu betrachten.

---

# Interessantes an der App

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
- [FFJKG](#ffjkg)
- [Einstellungen](#einstellungen)

## Designing

- Flutter unterstüzt Material 3! → sieht modern aus, erfordert keine weitere Arbeit
- MaterialApp Design hat [`useMaterial3: true`](https://github.com/AntonioAlbt/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/main.dart#L66)
- Drawer-Items ähnlich zu Material 3-`NavigationDrawer` gestaltet
  - gute Übersichtlichkeit
  - angenehme Farben und Größe
  - auch Meinungen von Freunden und Familie eingeholt
- Dark Mode hinzugefügt, kann ohne Neustart smooth geändert werden (wird von Flutter direkt unterstützt, [`ColorScheme.brightness`](https://github.com/AntonioAlbt/kepler_app/blob/0413b2a63be3ca92d8059f11a1346401a670533e/lib/main.dart#L243))
  - wird von allen Widgets unterstützt
  - im News-Browser umsetzen?
- Kepler-Farbpalette sollte mehr verwendet werden
- Design ist nicht allzu interessant, dafür sehr modern:
  - mehr Farben verwenden! -> "unterhaltsamer" anzuschauen
  - weniger runde Kanden? andere Formen?

## Navigationssystem

- ursprüngliche Entscheidung: Material3 NavigationDrawers
  - aber: Items nehmen sehr viel Platz weg
  - CustomDesign nicht (einfach) möglich?
  - Verschachtelung von Drawer-Items nicht möglich
- größtes Problem:
  - viele nötige Elemente, meine beste Lösungsidee: **verschachtelte Drawer-Items**
  - allerdings: keine gute Implementation dafür gefunden?
- Lösung:
  - also eigenes System dafür entwickelt, erlaubt komplette Bearbeitbarkeit (siehe [`drawer.dart`](https://github.com/AntonioAlbt/kepler_app/blob/main/lib/drawer.dart))
  - Design ähnlich wie Mat3 NavDrawers, aber kompakter und mit Möglichkeit für `children`
  - erlaubt jetzt auch verschiedene Aktionen in der Navigationsleiste pro Page
  - auch Überprüfungsfunktionen, ob Öffnen/Aufklappen möglich ist -> für StuPlan Erst-Datenerfassung
  - Einträge können auch:
    - ausgeblendet werden, z.B. Lehrerplan für Schüler - damit muss ich nicht das Array der Entries bei Runtime bearbeiten, sondern zeige einfach bestimmte Einträge daraus nicht an
    - gesperrt werden, z.B. um nicht angemeldeten Benutzern zu zeigen, was sie durch Anmeldung freischalten, und damit sie sich einfacher anmelden können

## Essensplan

- eigentlich: Bestellung und Abfrage per API direkt integrieren
- aber: DLS erlaubte mir das (auf Anfrage) nicht
- deshalb: Webseite-Link und Knopf, um die App zu installieren oder öffnen
- Plan: nochmal anfragen, Unterstützung von Schulleiter ausdrücken; anbieten, die offizielle Dart-Library vom Eigentümer vom Dienstleister der DLS zu benutzen

## Kepler-News-System

- kepler-chemnitz.de Wordpress-Post-API ist gesperrt ([`kepler-chemnitz.de/wp-json/wp/v2/posts`](https://kepler-chemnitz.de/wp-json/wp/v2/posts))
- deshalb verwende ich den RSS/Atom-Feed (auf [`kepler-chemnitz.de/?feed=atom`](https://kepler-chemnitz.de/?feed=atom) zu finden, paginated mit URL-Argument paged), um die Posts zu erfassen
- für genauere Ansichten des Artikels:
  - öffnet echte Post-URL in Custom WebView
  - Footer/Header werden durch JS entfernt
- *TODO: wenn möglich, Zugriff auf die API bekommen, um Posts besser anzuzeigen* (eher nicht, da Einbettung in die App die Sperre unnötig machen würde)
- News auch offline anzeigen:
  - News-Data in Cache als JSON (siehe [NewsEntryData](https://github.com/AntonioAlbt/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/tabs/news/news_data.dart#L7))
  - [`NewsEntries`](https://github.com/AntonioAlbt/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/tabs/news/news.dart#L49-L50) werden daraus generiert
  - Offline-Anzeige von News nicht möglich, da echter Inhalt (HTML) nicht gecached werden kann
- siehe [Benachrichtigungen](#benarichtigungen)
- News-"Widget" zur Homepage hinzugefügt
  - App lädt neue News beim Öffnen der App
  - neueste 3 News sichtbar auf App-Homepage

## Kepler-Stundenplan

- Datenabfrage:
  - eigene Schnittstelle plus Modelle für Indiware-API geschrieben: [`indiware.dart`](https://github.com/AntonioAlbt/kepler_app/blob/af6d4de02d25b093c7d09193d71a6612f36cc6e8/lib/libs/indiware.dart)
  - zusätzlich Management von Caching für alle Daten -> `IndiwareDataManager` aus [`ht_data.dart`](https://github.com/AntonioAlbt/kepler_app/blob/af6d4de02d25b093c7d09193d71a6612f36cc6e8/lib/tabs/hourtable/ht_data.dart)
  - alles wird gecached, Daten älter als 3 Tage werden beim Start gelöscht
  - `Klassen.xml` (Plan-Datei, die nur für allgemeine Infos genutzt wird) wird nach 30 Tagen erneuert ([`Änderungszeitpunkt vor mehr als 30 Tagen`](https://github.com/AntonioAlbt/kepler_app/blob/af6d4de02d25b093c7d09193d71a6612f36cc6e8/lib/tabs/hourtable/ht_data.dart#L169))
- Anmeldedaten werden bei Anmeldung von LernSax abgefragt
  - wenn das scheitert, wird Benutzer gefragt
  - mehr Infos: siehe `lernsax_data/info.md`
- Abfrage von Klasse/Lehrer und Kursen (bei Klasse):
  - je nach Benutzertyp (Lehrer oder Schüler/Eltern)
  - beim ersten Öffnen (Nichtvorhandensein von ausgewählten Daten)
  - InfoScreen mit Abfrage von Klasse/Lehrer
  - bei Schüler/Eltern: Abfrage der Kurse der Klasse -> zur Filterung der Anzeige
- "Dein/Ihr Stundenplan":
  - auf Basis der ausgewählten Daten Anzeige der Unterrichtsstunden
  - nicht anpassbar -> zeigt immer Daten von `plan.kepler-chemnitz.de` an (wie alle Datenansichten)
- Lehrerpläne (nur für Lehrer angezeigt):
  - verwendet Indiware-Daten für Lehrer
  - wie Klassenpläne, nur für alle Lehrer
- Klassenpläne:
  - wie eigener Stundenplan, nur für beliebige Klasse (ignoriert ausgewählte Kurse)
  - speichert zuletzt ausgewählte Klasse (auch für Lehrer- und Raumpläne)
- Alle Vertretungen:
  - ähnlich wie Anzeige an TV in Schule
  - zeigt nur `VPLesson`s mit Änderungen oder Infos
- Freie Räume:
  - durch Fokussierung auf JKG gut umsetzbar -> Liste von Raum-Codes hardcoded (muss halt nach dem Gebäudeupdate aktualisiert werden)
  - erlaubt bessere Bestimmung der freien Räume
  - erlaubt Kategorisierung und schönere + übersichtlichere Anzeige der Räume für den Benutzer (später konfigurierbar)
- Raumpläne:
  - aus Raumliste und Unterrichtsdaten abgeleitet
  - dadurch nicht 100 % zuverlässig
  - gerade für Räume mit seperater Liste für Verwendung (z.B. Aula) nicht anwendbar -> werden nicht mit angezeigt
- Anzeige:
  - allgemeine Biblothek mit Widgets für Stundenplan-Darstellung, mithilfe der Datenmodelle von `indiware.dart`
  - Extra-Infos per Dialog beim Antippen eines Eintrages
    - hat mir persönlich gefehlt
    - zeigt, wenn möglich, über `VPSubject.subjectID` mehr Infos zum Fach + Lehrer, bei dem in der entsprechenden Stunde eigentlich Unterricht gewesen wäre, an
    - kurze, knappe Übersicht über die Daten zu einer Unterrichtsstunde im Vertretungsplan
  - gleiche Basis sorgt für gleiches, einheitliches Design zum Tagauswählen und zur Darstellung der Stunden für alle Daten
- alle Daten werden nur aus Schüler- bzw. Lehrerplandaten abgeleitet -> können teilweise unzuverlässig sein, aber dadurch keine extra Komplexität durch Abfragen von anderen Daten
- damit können auch Schüler auf Raumpläne (und theoretisch auch einfache Lehrerpläne \[tatsächliche Implementierung ausstehend?\]) zugreifen
- Fach bei "Aufgaben auf LernSax erledigen" automatisch als ausgefallen markieren (wenn `Lehrer == ""`)? -> scheint immer zu passen

## Daten-Speicherung

- Datenschutz:
  - sollte kein Problem sein
  - da *keine neuen Server* benötigt werden sollen -> keine neue Datenspeicherung
  - Anmeldedaten werden nur lokal in der App gespeichert
- Anmeldedaten sollen bei jedem Start der App überprüft werden
- Stundenplan-Auth-Daten für Schüler sollen von Lernsax abgefragt werden
- Rolle bestimmen:
  - Anmeldungsablauf:
    1. Mit LernSax anmelden
    2. Zugehörigkeit zu Johannes-Kepler-Gymnasium prüfen
    3. Wenn LernSax-Mail auf .eltern, .vati, .mutti, .tante oder .grosseltern endet: **Eltern**
    4. Mit Stundenplan-Daten anmelden
    5. Wenn Daten Zugriff auf Lehrerplan geben: **Lehrer**
    6. Wenn Daten Zugriff auf Schülerplan geben: **Schüler**
  - damit werden Rollen bestimmt
  - -> könnte durch automatische Abfrage von LernSax durch evtl. Lehrergruppe (wenn Mitglied = Lehrer) und allgemeine Institution mit Datei mit Indiware-Auth-Daten vereinfacht werden
  - Problem: Stundenplan-Anmeldedaten werden nicht ungültig
  - Lösung: da LernSax-Anmeldung auch überprüft wird, werden diese dann zur Überprüfung verwendet
- wenn kein Internet: Rolle als verifiziert ansehen, aber zur Änderung (und zum ersten Login) ist Internet nötig

## LernSax

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
  - Nachrichtenboard anschauen
  - wenn möglich: Übersicht für neue Dateien hinzufügen
  - für andere Funktionen, wie Dateien: auf LernSax-Messenger App verlinken

## Startseite

- aus jedem wichtigen Tab wird ein "Widget" zur Startseite hinzugefügt
- Reihenfolge und Sichtbarkeit soll anpassbar sein
- spezielles Widget für Stundenplan:
  - zeigt nur aktuelle Vertretungen für heutigen Tag (Info bei Wochenende)
  - mit "Link" zu eigentlichem Stundenplan

## FFJKG

- Unterstützung eigentlich garantiert, Absprache bei Stammtisch
- Bereitstellung eines Macs zu teuer -> iPhone vielleicht über Schule erhältlich, Mac wird virtuell simuliert
  - Problem: Verbindung von iPhone?
- Modus für zukünftige Eltern (-> ohne LernSax-Login) muss noch verbessert werden

## Einstellungen

- Farbschema auswählbar (auch Systemschema)
- Logins ändern (Problem: App muss neugestartet werden, damit Daten ordentlich geladen werden)
- Stundenplanzeugs ändern (auch als Navbar-Aktion)
- Ideen für Einstellungen:
  - ~~Farbschema ändern~~ ✅
  - blauen Rahmen für Stundenplan anpassbar, vielleicht als Gradient
  - ~~eigenen Hintergrund für App/Stundenplan-Views~~ (erstmal nicht, wäre sowieso kaum sichtbar)
  - Elemente der Navigation versteckbar machen
  - Reihenfolge + Sichtbarkeit der Widgets auf dem Home-Screen anpassbar machen
  - Benachrichtigungs-Kontrolle (welche, für was)
  - anpassbares App-Icon (mit `dynamic_flutter_icon`?)
  - Special Effects / "Lustiges":
    - Konfetti für Vertretungen in eigenem Plan / auf StuPlan-Widget
    - Lustige Sounds beim Antippen von manchen Knöpfen
    - Startup-Sound

## Benarichtigungen

- für News:
  - bevorzugt hätte ich Firebase-Push-Notifications verwendet - aber: das erfordert Integration mit WordPress (und erfordert Firebase-Projekt -> Datenschutz-Frage)
    - da das nicht möglich ist, muss App regelmäßig neue Artikel abfragen -> Pull-Prinzip
    - nicht so toll, aber nicht so schlimm, dass anderes nötig ist
  - `Workmanager` zum Erstellen eines Tasks verwenden
    - iOS-Kompatibilität fragwürdig!
  - damit wird alle 2 Stunden auf neue News überprüft
  - falls neue News verfügbar: Benachrichtigung wird gesendet (siehe [`sendNotification`](https://github.com/AntonioAlbt/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/libs/tasks.dart#L57-L65) in `tasks.dart`, verwendet API von [`notifications.dart`](https://github.com/AntonioAlbt/kepler_app/blob/3634ace5014b236d26bf24d50520c9c2f1c6f587/lib/libs/notifications.dart))
    - Benachrichtigungen scheinen aktuell iOS gar nicht zu unterstützen
    - erfordern extra Berechtigungen auf Android 13+ -> werden aktuell nicht angefragt
- für Stundenplan-Änderungen:
  - neue Idee
  - ähnliche Umsetzung wie News-Benachrichtigungen
- für LernSax-Benachrichtigungen:
  - nicht wirklich nötig
  - LernSax Messenger kann das schon, und eigentlich besser

## realistische? Erwartungen

- ich glaube halt einfach mal nicht, dass je ~~ein~~ zwei Lehrer oder Eltern die App verwenden werden
  - Stats/Analytics dazu wären nice, aber wohl kaum datenschutztechnisch vertretbar (bzw. erfordert Hintergrundserver)
- aber der Gedanke zählt xD
