# App-Dateien auf LernSax

## Warum?

Es gibt aktuell zwei Probleme:

1. Aktuell muss man sich zweimal anmelden, einmal für LernSax und einmal zum Stundenplan, da die Indiware-Login-Daten nicht auf LS zu finden sind.
2. Außerdem werden die Login-Daten verwendet, um zu ermitteln, ob der Benutzer ein Schüler oder ein Lehrer ist.
(Das könnte man bestimmt auch über die Angabe vom `user.type` von den LernSax-API-Login-Daten bestimmen, aber die sind nicht dokumentiert.)

## Was ist es?

Zwei Dateien:

- `Kepler-App-Daten.json` in den Institutionsdateien
- `Kepler-App-Daten.json` in der Lehrergruppe/-klasse

## Wie bringt das was?

Das löst zwei Probleme:

1. Zweiter Login fällt weg, da in den json-Dateien die Anmeldedaten eingetragen sind.
2. Bestimmung des Benutzers ist jetzt auf Basis der Zugriffsmöglichkeiten -> wenn Benutzer auf Lehrerdatei zugreifen kann (also in Lehrergruppe ist), dann ist es ein Lehrer; sonst Schüler oder Elternteil

## Was ist denn in den Dateien drin?

Tja, das ist ja die große Frage.

Datenmodell:

```json
{
    "info": "Diese Datei enthält die Daten für die Kepler-App, eine BeLL von Antonio A.",
    "letztes_update": "16.10.2023 21:19",
    "indiware": {
        "host": "https://plan.kepler-chemnitz.de/stuplanindiware",
        "user": "plan-benutzername",
        "password": "plan-passwort"
    },
    "is_teacher_data": false
}
```

`indiware.user`, `indiware.password` und `is_teacher_data` müssen entsprechend für die beiden Dateivarianten angepasst werden.

## Aber was bei Fehlern?

Mögliche Fehler:

- LernSax-Login von Institution oder Lehrergruppe/-klasse ändern sich
- Dateiinhalt wird geändert, aber ist dann ungültig
- Datei wird verschoben oder gelöscht

Das Ergebnis ist immer das gleiche: kein Zugriff mehr auf die Daten. Ach du Schande.

**Lösung:** Fallback auf aktuelles System

- Check auf Daten direkt mit LernSax-Login
- falls gefunden, überspringen der Stundenplan-Anmeldung
- passiert auch, falls die auf LernSax gefundenen Daten nicht funktionieren
