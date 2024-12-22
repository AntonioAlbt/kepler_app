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

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/drawer.dart';
import 'package:kepler_app/libs/custom_color_picker.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/lernsax.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/notifications.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/rainbow.dart';
import 'package:kepler_app/tabs/home/home.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

/// Tab für Einstellungen, zeigt mithilfe von settings_ui alle Einstellungen an
/// und nimmt Veränderungen direkt in Preferences vor (die meisten Einstellungen sind ziemlich selbsterklärend
/// oder entsprechend beschrieben)
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

/// Map aller als Startseiten auswählbaren Seiten (mapping: interne Page ID, von navigation.dart -> benutzerfreundl. Name)
/// Achtung: falls eine hier aufgelistete Seite eine Unterseite ist, muss der getter von Preferences.startNavPage
/// in libs/preferences.dart angepasst werden
final _startPageMap = {
  PageIDs.home: "Startseite",
  NewsPageIDs.news: "Kepler-News",
  StuPlanPageIDs.yours: "Persönlicher Stundenplan",
  StuPlanPageIDs.all: "Alle Vertretungen",
};

/// Map für alle verfügbaren Benachrichtigungstypen (mapping: Benachrichtigungs-Key -> benutzerfreundlicher Name)
final _notifKeyMap = {
  newsNotificationKey: "Neue Kepler-News",
  stuPlanNotificationKey: "Änderungen im Stundenplan",
};

class _SettingsTabState extends State<SettingsTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<Preferences>(
      builder: (context, prefs, _) {
        final sie = prefs.preferredPronoun == Pronoun.sie;
        final userType = Provider.of<AppState>(context, listen: false).userType;
        return SettingsList(
          platform: DevicePlatform.android,
          sections: [
            if (userType == UserType.nobody) SettingsSection(
              tiles: [
                SettingsTile(
                  title: const Text("Hinweis"),
                  description: Selector<Preferences, bool>(
                    selector: (ctx, prefs) => prefs.preferredPronoun == Pronoun.sie,
                    builder: (context, sie, _) => Text("${sie ? "Sie müssen" : "Du musst"} angemeldet sein, um die meisten Einstellungen zu ändern."),
                  ),
                ),
              ],
            ),
            /// Einstellungen sind grob in Navigations-Kategorien eingeteilt
            SettingsSection(
              title: const Text("Allgemeines"),
              tiles: [
                // the way this is implemented can cause minor desync and the dialog showing the wrong system theme, but it's not that big an issue
                /// falls ein Benutzer das System-Theme ändert, während er in den Einstellungen ist, zeigt dieser Dialog
                /// noch das alte Theme an (aber das ist ja mal vollkommen egal)
                selectionSettingsTile(
                  prefs.theme
                      .toString()
                      .replaceAll("System", "System (${(deviceInDarkMode ?? false) ? "Dunkel" : "Hell"})"),
                  AppTheme.values.map((val) {
                    if (val == AppTheme.system) {
                      return "System (${(deviceInDarkMode ?? false) ? "Dunkel" : "Hell"})";
                    } else {
                      return val.toString();
                    }
                  }).toList(),
                  "Farbmodus",
                  /// einigermaßen schlechter Code, normalerweise (siehe preferredPronoun), implementiert das Enum mit
                  /// auswählbaren Werten einfach toString und alles geht fein, aber hier soll das aktuelle System-
                  /// Theme mit erwähnt werden, weshalb es das hier dann so aussieht
                  /// - das müsste auch mit geändert werden, falls jemals mehr Themes hinzugefügt werden oder
                  /// AppTheme.toString geändert wird
                  (val) => prefs.theme = {"S": AppTheme.system, "D": AppTheme.dark, "H": AppTheme.light}[val.substring(0, 1)]!,
                ),
                /// es gibt bestimmt ein besseres Wort als "pronoun" für das deutsche Wort Anrede, allerdings ist es
                /// jetzt nur noch mit Portierungsaufwand möglich, die Benennung zu ändern und es sieht eh nie ein
                /// Benutzer wie das heißt - die Bedeutung ist ja nah genug
                selectionSettingsTile(prefs.preferredPronoun, Pronoun.values, "Bevorzugte Anrede", (val) => prefs.preferredPronoun = val),
                /// notificationSettingsTile ist eigentlich einfach ein selectionSettingsTile mit der Option für mehrere
                /// angewählte Elemente
                notificationSettingsTile(prefs.enabledNotifs.map((en) => _notifKeyMap[en]).where((e) => e != null).toList(), userType == UserType.nobody ? ["Neue Kepler-News"] : _notifKeyMap.values.toList(), "Benachrichtigungen", (selectedNow) {
                  prefs.enabledNotifs = selectedNow.map((e) => _notifKeyMap.entries.firstWhere((element) => element.value == e).key).toList().cast();
                }),
                /// Umsetzung siehe prefs.startNavPage und Verwendungen
                selectionSettingsTile(
                  _startPageMap[prefs.startNavPage],
                  _startPageMap.values.toList(),
                  "Seite, die beim Öffnen angezeigt wird",
                  (val) => prefs.startNavPage = _startPageMap.entries.firstWhere((e) => e.value == val).key,
                  disabled: userType == UserType.nobody,
                  addCommaAfterTitle: true,
                ),
                /// da der Benutzer hier nichts ändern kann, gibt es tatsächlich mal ein passendes vorgefertigtes
                /// SettingsTile, was bei Tippen einfach etwas ausführt
                SettingsTile.navigation(
                  onPressed: (context) {
                    Navigator.push(context, MaterialPageRoute(builder: sharePreferencesPageBuilder()));
                  },
                  title: const Text("Einstellungen exportieren"),
                  description: const Text("um diese auf einem anderen Gerät benutzen zu können"),
                ),
                SettingsTile.navigation(
                  onPressed: (context) {
                    loadFromExportJson(context).then((result) {
                      switch (result) {
                        case "success":
                          setState(() {});
                          showSnackBar(text: "Einstellungen erfolgreich importiert.", duration: const Duration(seconds: 2));
                          break;
                        case "abort":
                          break;
                        case "import_error":
                          showSnackBar(text: "Fehler beim Import.", error: true, clear: true);
                        default:
                          /// sollte nicht eintreten können
                          break;
                      }
                    });
                  },
                  title: const Text("Einstellungen importieren"),
                  description: const Text("von einem anderen Gerät exportierte Einstellungen übernehmen"),
                ),
                SettingsTile.navigation(
                  title: Text.rich(
                    TextSpan(
                      children: [
                        /// zur Hervorhebung der "schlimmen" Bedeutung dieser Funktion wird das Icon mit angezeigt
                        WidgetSpan(child: Icon(Icons.warning_rounded, color: hasDarkTheme(context) ? Colors.amber : Colors.yellow.shade900, size: 22)),
                        const TextSpan(text: " Abmelden und neu anmelden"),
                      ],
                    ),
                  ),
                  description: const Text("Abmelden und neu mit LernSax anmelden"),
                  onPressed: (context) => showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Wirklich fortfahren?"),
                      content: Text("${sie ? "Wollen Sie sich" : "Willst Du Dich"} wirklich neu anmelden? Falls ja, wird die Verbindung zu LernSax getrennt und die Anmeldung ist erneut nötig."),
                      actions: [
                        TextButton(
                          onPressed: () {
                            final creds = Provider.of<CredentialStore>(context, listen: false);
                            Provider.of<InternalState>(context, listen: false).introShown = false;
                            () async {
                              if (creds.lernSaxToken != null && creds.lernSaxLogin != null) {
                                // try to unregister this app from LernSax, but don't care if it doesn't work
                                // (most users don't check their registered apps on LernSax anyways)
                                // waiting for this to complete is still necessary
                                /// auch für alle hinzugefügten Konten versuchen, App-Registrierung zu trennen
                                for (final entry in creds.alternativeLSLogins.asMap().entries) {
                                  final i = entry.key, login = entry.value;
                                  if (creds.alternativeLSLogins.length <= i) break;
                                  final token = creds.alternativeLSTokens[i];
                                  try {
                                    await unregisterApp(login, token);
                                  } catch (_) {}
                                }
                                try {
                                  await unregisterApp(creds.lernSaxLogin!, creds.lernSaxToken!);
                                } catch (_) {}
                              }
                              if (!mounted) return;

                              Navigator.pop(this.context);
                              showLoginScreenAgain(closeable: false);
                            }();
                          },
                          child: const Text("Ja, abmelden"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Nein, abbrechen"),
                        ),
                      ],
                    ),
                  ),
                ),
                SettingsTile.navigation(
                  title: Text("Navigationseinträge ausblenden"),
                  description: Text("Einträge im Navigationsmenü ausblenden"),
                  onPressed: (_) => showDialog(context: context, builder: (ctx) => NavHideDialog()),
                ),
              ],
            ),
            SettingsSection(
              title: const Text("Startseite"),
              tiles: [
                rainbowSwitchTile(
                  initialValue: prefs.showHomeWidgetEditOptions && userType != UserType.nobody,
                  onToggle: (val) => prefs.showHomeWidgetEditOptions = val,
                  title: const Text("Bearbeiten-Knöpfe anzeigen"),
                  description: const Text("z.B. \"Ausblenden\" und \"Verschieben\" bei Widgets anzeigen"),
                  enabled: userType != UserType.nobody,
                ),
                SettingsTile.navigation(
                  title: const Text("Widget-Reihenfolge ändern"),
                  description: const Text("Reihenfolge der Informationsblöcke auf der Startseite ändern"),
                  onPressed: (_) => openReorderHomeWidgetDialog(),
                  enabled: userType != UserType.nobody,
                ),
              ],
            ),
            SettingsSection(
              title: const Text("Stundenplan"),
              tiles: [
                /// ursprünglich hinzugefügt, als es nur einen Stundenplan gab - bearbeitet also immer den primären
                // TODO: könnte angepasst werden, dass man gefragt wird, welchen Stundenplan man ändern bzw. hinzufügen will
                SettingsTile.navigation(
                  title: Text(userType == UserType.teacher ? "Lehrer ändern" : "Klasse oder Belegung ändern"),
                  description: Text("${sie ? "Ihre" : "Deine"} ${userType == UserType.teacher ? "Lehrer-Abkürzung" : "Klasse und/oder belegte Fächer ändern"} (für ${sie ? "Ihren" : "Deinen"} primären Stundenplan)"),
                  onPressed: (_) {
                    final state = Provider.of<AppState>(context, listen: false);
                    state.infoScreen ??= (state.userType != UserType.teacher)
                        ? stuPlanPupilIntroScreens()
                        : stuPlanTeacherIntroScreens();
                  },
                  enabled: userType != UserType.nobody,
                ),
                /// warum nur einmal? weil es sonst nicht so einfach ist, zu erfassen, wann das passieren soll
                /// - es könnte natürlich auch jedes Mal beim Öffnen der App oder Seite sein, aber ich fand es so besser
                /// - auf modernen Handys wird eh fast alles im RAM gehalten, da gibt es kaum mehr neu öffnen
                rainbowSwitchTile(
                  initialValue: prefs.reloadStuPlanAutoOnceDaily,
                  onToggle: (val) => prefs.reloadStuPlanAutoOnceDaily = val,
                  title: const Text("Beim Öffnen automatisch aktualisieren"),
                  description: const Text("passiert einmal täglich beim Öffnen des Stundenplanes"),
                  enabled: userType != UserType.nobody,
                ),
                /// dafür kann HMTime von indiware.dart gleich passend wiederverwendet werden, weil es einfach zu
                /// serialisieren geht (und ansonsten nur TimeOfDay von Flutter für Datentyp Uhrzeit ohne Datum
                /// verwendet werden kann)
                SettingsTile.navigation(
                  title: const Text("Zeit für nächsten Tag bzw. Plan"),
                  // description: const Text("ab welcher Uhrzeit der Plan für den nächsten Tag angezeigt werden soll"),
                  value: Text(prefs.timeToDefaultToNextPlanDay.toString()),
                  onPressed: (context) => showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: prefs.timeToDefaultToNextPlanDay.hour,
                      minute: prefs.timeToDefaultToNextPlanDay.minute,
                    ),
                  ).then((picked) {
                    if (picked != null) {
                      prefs.timeToDefaultToNextPlanDay = HMTime(picked.hour, picked.minute);
                    }
                  }),
                  enabled: userType != UserType.nobody,
                ),
                ColorSelectSettingsTile(
                  title: "Rahmenfarbe für Stundenplanliste",
                  current: prefs.stuPlanDataAvailableBorderColor,
                  updateData: (col) => prefs.stuPlanDataAvailableBorderColor = col!,
                  disabled: prefs.stuPlanDataAvailableBorderWidth == 0 || userType == UserType.nobody,
                ),
                /// da ich die Beschreibung auf den SettingsTile-s schon für die Anzeige der aktuell ausgewählten Farbe
                /// verwende, kann ich dort nicht genau erklären, was die zweite Farbe eigentlich macht
                /// - also schreib ich das einfach in den Titel rein
                ColorSelectSettingsTile(
                  title: "Rahmenfarbe 2 für Stundenplanliste - Farbe für Farbverlauf",
                  current: prefs.stuPlanDataAvailableBorderGradientColor,
                  updateData: (col) => prefs.stuPlanDataAvailableBorderGradientColor = col,
                  nullAvailable: true,
                  disabled: prefs.stuPlanDataAvailableBorderWidth == 0 || userType == UserType.nobody,
                ),
                /// damit hier die Einheit entsprechend angezeigt werden kann, wird " px" an alles angehangen
                /// und beim Speichern entsprechend wieder gelöscht
                selectionSettingsTile(
                  "${prefs.stuPlanDataAvailableBorderWidth.round()} px${prefs.stuPlanDataAvailableBorderWidth == 0 ? " (kein Rahmen)" : ""}",
                  [ "0 px (kein Rahmen)", "1 px", "3 px", "4 px", "6 px", "10 px", "15 px", "20 px" ],
                  "Rahmendicke für Stundenplanliste",
                  (val) {
                    prefs.stuPlanDataAvailableBorderWidth = double.parse(val.split(" px")[0]);
                  },
                  disabled: userType == UserType.nobody,
                ),
                /// auskommentiert, da "Aufgaben auf LernSax" im Vertretungsplan nicht mehr so verwendet wird
                // rainbowSwitchTile(
                //   initialValue: prefs.considerLernSaxTasksAsCancellation,
                //   onToggle: (val) => prefs.considerLernSaxTasksAsCancellation = val,
                //   title: const Text("\"$cancellationALaLernSax\" als Ausfall ansehen"),
                //   description: const Text("auch wenn das kein richtiger Ausfall ist"),
                //   enabled: userType != UserType.nobody,
                // ),
                // rainbowSwitchTile(
                //   initialValue: prefs.considerLernSaxTasksAsCancellation ? prefs.showLernSaxCancelledLessonsInRoomPlan : true,
                //   onToggle: (val) => prefs.showLernSaxCancelledLessonsInRoomPlan = val,
                //   title: const Text("LernSax-Ausfall im Raumplan anzeigen"),
                //   description: const Text("Stunden mit \"$cancellationALaLernSax\" im Raumplan anzeigen"),
                //   enabled: prefs.considerLernSaxTasksAsCancellation && userType != UserType.nobody,
                // ),
                rainbowSwitchTile(
                  initialValue: prefs.enableInfiniteStuPlanScrolling,
                  onToggle: (val) => prefs.enableInfiniteStuPlanScrolling = val,
                  title: const Text("Unendlich blättern"),
                  description: const Text("Unendlich Tage zurück- und vorblättern ermöglichen + Aktion zum Zurückspringen"),
                  enabled: userType != UserType.nobody,
                ),
                rainbowSwitchTile(
                  initialValue: prefs.stuPlanShowExams,
                  onToggle: (val) => prefs.stuPlanShowExams = val,
                  title: const Text("Klausuren anzeigen"),
                  description: const Text("zeigt Klausuren für alle Klassen an, falls vorhanden"),
                  enabled: userType != UserType.nobody,
                ),
                rainbowSwitchTile(
                  initialValue: prefs.stuPlanShowLastRoomUsage,
                  onToggle: (val) => prefs.stuPlanShowLastRoomUsage = val,
                  title: const Text("Icon für Räume mit letzter Verwendung"),
                  description: const Text("Stunden mit Räumen, die am ausgewählten Tag das letzte Mal verwendet werden, bekommen ein besonderes Icon"),
                  enabled: userType != UserType.nobody,
                ),
                rainbowSwitchTile(
                  initialValue: prefs.showYourPlanAddDropdown,
                  onToggle: (val) => prefs.showYourPlanAddDropdown = val,
                  title: const Text("Möglichkeit für Stundenpläne hinzufügen anzeigen"),
                  description: Text("aktivieren, um auf Seite \"${sie ? "Ihr" : "Dein"} Stundenplan\" Stundenpläne hinzufügen können"),
                  enabled: userType != UserType.nobody && Provider.of<StuPlanData>(context, listen: false).altSelectedClassNames.isEmpty,
                ),
              ],
            ),
            /// da die Kategorie LernSax selbst nur so wenig Inhalt hat, gibt es auch kaum Einstellungen
            SettingsSection(
              title: const Text("LernSax"),
              tiles: [
                rainbowSwitchTile(
                  initialValue: prefs.lernSaxAutoLoadMailOnScrollBy,
                  onToggle: (val) => prefs.lernSaxAutoLoadMailOnScrollBy = val,
                  title: const Text("LernSax-Mails beim ersten Vorbeiscrollen einmalig herunterladen"),
                  description: const Text("das ist nötig, damit die Anhänge geladen werden können (verbraucht mehr Daten)"),
                  enabled: userType != UserType.nobody,
                ),
              ],
            ),
            /// Kategorie für Einstellungen, die unterhaltsam bzw. lustig bzw. random sind
            SettingsSection(
              title: const Text("Lustiges"),
              tiles: [
                rainbowSwitchTile(
                  initialValue: prefs.confettiEnabled,
                  onToggle: (val) => prefs.confettiEnabled = val,
                  title: const Text("🎉 Konfetti aktivieren 🎉"),
                  description: const Text("z.B. bei Ausfall oder schulfreien Tagen"),
                  enabled: userType != UserType.nobody,
                ),
                rainbowSwitchTile(
                  initialValue: prefs.rainbowModeEnabled,
                  onToggle: (val) => prefs.rainbowModeEnabled = val,
                  title: const Text("🏳️‍🌈 Regenbogenmodus aktivieren"),
                  description: const Text("Farbe vieler Oberflächen wird zu Regenbogenanimation geändert"),
                  // enabled: userType != UserType.nobody,
                ),
                /*rainbowSwitchTile(
                  initialValue: prefs.aprilFoolsEnabled,
                  onToggle: (val) => prefs.aprilFoolsEnabled = val,
                  title: const Text("Aprilscherze aktivieren"),
                  description: const Text("nur am 1. April"),
                )*/
              ],
            ),
            SettingsSection(
              title: const Text("Debug-Aufzeichnungen"),
              tiles: [
                rainbowSwitchTile(
                  initialValue: prefs.loggingEnabled,
                  onToggle: (val) {
                    if (val) {
                      prefs.loggingEnabled = true;
                      return;
                    }
                    /// da es für mich einfacher ist, wenn die Logs immer aktiviert sind, gibt es zum Deaktivieren
                    /// eine extra Nachfrage
                    showDialog(context: context, builder: (ctx) => AlertDialog(
                      title: const Text("Wirklich ändern?"),
                      content: const Text("Soll diese Einstellung wirklich geändert werden? Die Debug-Aufzeichnungen werden dann zukünftig nicht mehr gespeichert, und können nicht zur Fehlerbehebung genutzt werden."),
                      actions: [
                        TextButton(onPressed: () {
                          prefs.loggingEnabled = false;
                          Navigator.pop(ctx);
                        }, child: const Text("Bestätigen")),
                        TextButton(onPressed: () {
                          Navigator.pop(ctx);
                        }, child: const Text("Abbrechen")),
                      ],
                    ));
                  },
                  title: const Text("Aufzeichnungen aktivieren"),
                  /// "bedrohlicher" Text
                  description: Selector<Preferences, bool>(
                    selector: (_, prefs) => prefs.preferredPronoun == Pronoun.sie,
                    builder: (context, sie, _) => Text("Nur ändern, wenn ${sie ? "Sie wissen, was Sie tun!" : "Du weißt, was du tust!"}"),
                  ),
                ),
                selectionSettingsTile(
                  "${prefs.logRetentionDays} Tage",
                  [ "3 Tage", "7 Tage", "14 Tage", "30 Tage", "90 Tage", "180 Tage" ],
                  "Speicherdauer für Aufzeichnungen",
                  (val) {
                    prefs.logRetentionDays = int.parse(val.split(" Tage")[0]);
                  },
                  disabled: prefs.loggingEnabled == false,
                ),
                SettingsTile.navigation(
                  title: Text("VLANT-LogUp-Host"),
                  description: Text("aktuell: ${prefs.logUpHost ?? "keiner"}"),
                  onPressed: (ctx) {
                    showDialog<String?>(context: ctx, builder: (ctx) => HostEntryDialog(host: prefs.logUpHost ?? "")).then((host) {
                      if (host != null) {
                        prefs.logUpHost = host == "clear" ? null : host;
                      }
                    });
                  },
                ),
                SettingsTile.navigation(
                  title: Text("Infos zu VLANT-LogUp"),
                  description: Text("Mehr Informationen zu LogUp"),
                  onPressed: (ctx) {
                    showDialog<String?>(context: ctx, builder: (ctx) => AlertDialog(
                      title: Text("VLANT-LogUp"),
                      content: Text("""LogUp ist ein Dienst, um Aufzeichnungen der Kepler-App direkt an den Ersteller zu übermitteln.
Dabei kann man direkt aus der App die Aufzeichnungen hochladen.\nFür LogUp gelten seperate Datenschutzbedingungen. Vor allem werden Aufzeichnungen unverschlüsselt auf dem Server gespeichert."""),
                      actions: [
                        TextButton(
                          onPressed: () => launchUrl(
                            Uri(scheme: "https", host: prefs.logUpHost, path: "/datenschutz"),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Text("Datenschutzerkl. öffnen"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text("OK"),
                        ),
                      ],
                    ));
                  },
                ),
                if (kDebugFeatures) SettingsTile.navigation(
                  title: Text("Clear StuPlanData"),
                  onPressed: (ctx) {
                    Provider.of<StuPlanData>(ctx, listen: false).clearData();
                    showSnackBar(text: "cleared StuPlanData");
                  },
                ),
              ],
            ),
          ],
        );
      }
    );
  }
}

/// Eintrag für eine Einstellung, bei der ein Element aus einer Liste von Elementen ausgesucht werden kann
SettingsTile selectionSettingsTile<T>(T data, List<T> values, String title, void Function(T val) updateData, {bool disabled = false, bool addCommaAfterTitle = false}) {
  return SettingsTile.navigation(
    title: Text(title),
    value: Text(data.toString()),
    onPressed: (ctx) => showDialog(context: ctx, builder: (ctx) => AlertDialog(
      title: Text("$title${addCommaAfterTitle ? "," : ""} auswählen", style: const TextStyle(fontSize: 20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: values.map((val) => InkWell(
            onTap: () {
              updateData(val);
              Navigator.pop(ctx);
            },
            child: ListTile(
              title: Text(
                val.toString(),
                style: TextStyle(
                  fontWeight: (data == val) ? FontWeight.bold : null,
                ),
              ),
            ),
          )).toList(),
        ),
      ),
    )),
    enabled: !disabled,
  );
}

/// Eintrag für die Benachrichtigungseinstellung (bei der mehrere Elemente aus einer Liste von Elementen ausgesucht
/// werden können - allerdings angepasst speziell auf Benachrichtigungen)
SettingsTile notificationSettingsTile<T>(List<T> selected, List<T> values, String title, void Function(List<dynamic> selectedNow) updateData, {bool disabled = false}) {
  // return CustomSettingsTile(child: MultiSelectionSettingsDialog(selected: selected, values: values, title: title, updateData: updateData));
  return SettingsTile.navigation(
    title: Text(title),
    value: Text(selected.isNotEmpty ? selected.map((e) => e.toString()).join(", ") : "nichts ausgewählt"),
    onPressed: (ctx) => showDialog(
      context: ctx,
      builder: (ctx) => NotificationSettingsDialog(selected: selected, values: values, title: title, updateData: updateData),
    ),
    enabled: !disabled,
  );
}

/// ein selectionSettingsTile, bei dem der Schalter (wenn aktiviert) mit Regenbogenfarben animiert wird
CustomSettingsTile rainbowSwitchTile({
  required bool? initialValue,
  required dynamic Function(bool)? onToggle,
  Color? activeSwitchColor,
  Widget? leading,
  Widget? trailing,
  required Widget title,
  Widget? description,
  dynamic Function(BuildContext)? onPressed,
  bool enabled = true,
  Key? key,
}) {
  return CustomSettingsTile(
    child: RainbowWrapper(
      builder: (context, rcolor) {
        return SettingsTile.switchTile(
          initialValue: initialValue,
          onToggle: onToggle,
          activeSwitchColor: rcolor ?? activeSwitchColor,
          leading: leading,
          trailing: trailing,
          title: title,
          description: description,
          onPressed: onPressed,
          enabled: enabled,
          key: key,
        );
      }
    ),
  );
}

/// Helfer für notificationSettingsTile, da der Dialog dafür State braucht (um die neuen Elemente erst bei Tippen auf
/// "Bestätigen" abzusenden)
class NotificationSettingsDialog<T> extends StatefulWidget {
  final List<T> selected;
  final List<T> values;
  final String title;
  final void Function(List<dynamic> selectedNow) updateData;

  const NotificationSettingsDialog({super.key, required this.selected, required this.values, required this.title, required this.updateData});

  @override
  State<NotificationSettingsDialog> createState() => _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState<T> extends State<NotificationSettingsDialog<T>> {
  List<T> selected = <T>[];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("${widget.title} auswählen", style: const TextStyle(fontSize: 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.values.map((val) => CheckboxListTile(
          value: selected.contains(val),
          title: Text(
            val.toString(),
            // style: TextStyle(
            //   fontWeight: (selected.contains(val)) ? FontWeight.bold : null,
            // ),
          ),
          onChanged: (checked) {
            if (checked == true && !selected.contains(val)) {
              selected.add(val);
              setState(() => ());
            } else if (checked == false && selected.contains(val)) {
              selected.remove(val);
              setState(() => selected = selected..remove(val));
            }
          },
        )).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen"),
        ),
        TextButton(
          onPressed: () {
            if (selected.isNotEmpty) {
              checkNotificationPermission().then((notifsAllowed) {
                if (notifsAllowed) {
                  widget.updateData(selected);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                } else {
                  /// falls keine Benachrichtigungen erlaubt, auch keine als ausgewählt speichern
                  requestNotificationPermission().then((requestSuccessful) {
                    if (requestSuccessful) {
                      widget.updateData(selected);
                    } else {
                      widget.updateData(<T>[]);
                      showSnackBar(text: "Keine Zustimmung erteilt. Wir werden keine Benachrichtigungen senden.", error: true);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  });
                }
              });
            } else {
              widget.updateData(selected);
              Navigator.pop(context);
            }
          },
          child: const Text("Bestätigen"),
        ),
      ],
    );
  }

  @override
  void initState() {
    selected.addAll(widget.selected);
    super.initState();
  }
}

/// Eintrag für Farbauswahl-Einstellung
class ColorSelectSettingsTile extends AbstractSettingsTile {
  const ColorSelectSettingsTile({
    super.key,
    required this.title,
    required this.current,
    required this.updateData,
    this.nullAvailable = false,
    this.disabled = false,
  });

  final String title;
  final Color? current;
  final void Function(Color? data) updateData;
  final bool nullAvailable;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return SettingsTile.navigation(
      enabled: !disabled,
      title: Text(title),
      description: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: "Aktuelle Farbe: "),
            if (current != null) WidgetSpan(
              child: Transform.translate(
                offset: const Offset(1, -1),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: current,
                  ),
                ),
              ),
            ),
            TextSpan(text: current != null ? " #${current?.value.toRadixString(16).padLeft(8, '0')}" : "keine"),
          ],
        ),
      ),
      onPressed: (context) => showDialog(
        context: context,
        builder: (context) => CSTileColorSelectDialog(
          updateData: updateData,
          current: current,
          nullAvailable: nullAvailable,
        ),
      ),
    );
  }
}

/// Auswahldialog für Farbauswahl-Einstellung
class CSTileColorSelectDialog extends StatefulWidget {
  const CSTileColorSelectDialog({
    super.key,
    required this.updateData,
    required this.current,
    required this.nullAvailable,
  });

  final void Function(Color? data) updateData;
  final Color? current;
  final bool nullAvailable;

  @override
  State<CSTileColorSelectDialog> createState() => _CSTileColorSelectDialogState();
}

class _CSTileColorSelectDialogState extends State<CSTileColorSelectDialog> {
  late Color selected;

  @override
  void initState() {
    selected = widget.current ?? keplerColorBlue;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final customColor = widget.current != null && ![keplerColorBlue, keplerColorOrange, keplerColorYellow].contains(widget.current);
    return AlertDialog(
      title: const Text("Farbe ändern"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            onTap: () {
              widget.updateData(keplerColorBlue);
              Navigator.pop(context);
            },
            title: Text(
              "Kepler-Farbe: Blau",
              style: TextStyle(
                fontWeight: (widget.current == keplerColorBlue) ? FontWeight.bold : null,
              ),
            ),
            trailing: Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: keplerColorBlue,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          ListTile(
            onTap: () {
              widget.updateData(keplerColorOrange);
              Navigator.pop(context);
            },
            title: Text(
              "Kepler-Farbe: Orange",
              style: TextStyle(
                fontWeight: (widget.current == keplerColorOrange) ? FontWeight.bold : null,
              ),
            ),
            trailing: Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: keplerColorOrange,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          ListTile(
            onTap: () {
              widget.updateData(keplerColorYellow);
              Navigator.pop(context);
            },
            title: Text(
              "Kepler-Farbe: Gelb",
              style: TextStyle(
                fontWeight: (widget.current == keplerColorYellow) ? FontWeight.bold : null,
              ),
            ),
            trailing: Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: keplerColorYellow,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          ListTile(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Eigene Farbe auswählen"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomHueRingPicker(
                        pickerColor: selected,
                        onColorChanged: (col) {
                          widget.updateData(col);
                          setState(() {
                            selected = col;
                          });
                        },
                        portraitOnly: true,
                        // labelTypes: const [],
                        // pickerAreaHeightPercent: 0.5,
                        enableAlpha: false,
                        colorPickerHeight: 200,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () {
                      Navigator.pop(context);
                    }, child: const Text("Fertig")),
                  ],
                ),
              // ignore: use_build_context_synchronously
              ).then((_) => Navigator.pop(context));
            },
            title: Text(
              "Eigene Farbe",
              style: TextStyle(
                fontWeight: customColor ? FontWeight.bold : null,
              ),
            ),
            subtitle: customColor ? const Text("tippen, um zu ändern") : null,
            trailing: customColor
              ? Container(
                  height: 24,
                  width: 24,
                  decoration: BoxDecoration(
                    color: selected,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
              : null,
          ),
          if (widget.nullAvailable) ListTile(
            onTap: () {
              widget.updateData(null);
              Navigator.pop(context);
            },
            title: Text(
              "Keine",
              style: TextStyle(
                fontWeight: (widget.current == null) ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// weil settings_ui immer eine Liste von AbstractSettingsTile-s will, habe ich diesen Wrapper erstellt, der einfach
/// das angegebene Widget zurückgibt
class CustomSettingsTile extends AbstractSettingsTile {
  final Widget child;

  const CustomSettingsTile({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class HostEntryDialog extends StatefulWidget {
  final String host;

  const HostEntryDialog({super.key, required this.host});

  @override
  State<HostEntryDialog> createState() => _HostEntryDialogState();
}

class _HostEntryDialogState extends State<HostEntryDialog> {
  late TextEditingController _controller;
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final sie = Provider.of<Preferences>(context, listen: false).preferredPronoun == Pronoun.sie;
    return AlertDialog(
      title: Text("VLANT-LogUp-Host ändern"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("LogUp ist ein Dienst, der zum Übermitteln von Debug-Aufzeichnungen dient."),
            Text("Hier kann ein anderer Zielserver eingegeben werden. Dabei wird https-Zugriff erfordert.\n"),
            Text("Durch das Speichern ${sie ? "stimmen Sie" : "stimmst Du"} den Datenschutzbedingungen des Servers zu, unter https://${_controller.text == "" ? "(Host)" : _controller.text}/datenschutz."),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _controller,
              ),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text("Fehler: $_error"),
            ),
            if (_loading) LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text("Abbrechen"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, "clear"),
          child: Text("Zurücksetzen"),
        ),
        TextButton(
          onPressed: () {
            if (!_controller.text.contains(".")) {
              setState(() => _error = "Host enthält keinen \".\" - keine gültige Domain/IP.");
              return;
            }
            process();
          },
          child: Text("Speichern"),
        ),
      ],
    );
  }

  @override
  void initState() {
    _controller = TextEditingController(text: widget.host);
    super.initState();
  }

  Future<void> process() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    final Uri uri;
    try {
      uri = Uri(scheme: "https", host: _controller.text, path: "/api/ping");
    } catch (_) {
      setState(() {
        _error = "Ungültiger Host.";
        _loading = false;
      });
      return;
    }

    final dynamic json;
    try {
      final res = await http.get(uri);
      json = jsonDecode(res.body);
    } catch (_) {
      setState(() {
        _error = "Kommunikation mit Host gescheitert. Ist die Instanz richtig eingerichtet?";
        _loading = false;
      });
      return;
    }

    if (json is! Map || json["service"] != "logup") {
      setState(() {
        _error = "Keine funktionierende LogUp-Instanz.";
        _loading = false;
      });
      return;
    }

    if (!mounted) return;
    showSnackBar(text: "LogUp-Host zu \"${_controller.text}\" geändert.");
    Navigator.pop(context, _controller.text);
  }
}

class NavHideDialog extends StatefulWidget {
  const NavHideDialog({super.key});

  @override
  State<NavHideDialog> createState() => _NavHideDialogState();
}

class _NavHideDialogState extends State<NavHideDialog> {
  @override
  Widget build(BuildContext context) {
    final prefs = Provider.of<Preferences>(context, listen: false);
    final userType = Provider.of<AppState>(context, listen: false).userType;
    return AlertDialog(
      title: Text("Einträge ausblenden"),
      content: SizedBox(
        height: MediaQuery.sizeOf(context).height * .5,
        width: MediaQuery.sizeOf(context).width,
        child: AnimatedBuilder(
          animation: prefs,
          builder: (ctx, _) => ListView(
            shrinkWrap: true,
            children: destinations.map((dest) {
              ListTile? genLT(NavEntryData data, bool child, bool parentHidden) {
                if (dest.isVisible?.call(context) == false || data.visibleFor?.contains(userType) == false) return null;
                final hidden = prefs.hiddenNavIDs.contains(data.id);
                final startpage = prefs.startNavPageIDs.contains(data.id);
                return ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: (data.label is Text) ? Text("${child ? " - " : ""}${(data.label as Text).data}") : (data.id == StuPlanPageIDs.yours) ? Text(" - Eigener Plan") : data.label,
                      ),
                      IconButton.outlined(
                        onPressed: (data.ignoreHiding == true || parentHidden || startpage) ? null : () => hidden ? prefs.removeHiddenNavID(data.id) : prefs.addHiddenNavID(data.id),
                        icon: Icon((hidden || parentHidden) ? MdiIcons.eyeOff : MdiIcons.eye),
                      ),
                    ],
                  ),
                  subtitle: data.children?.isNotEmpty == true ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [if (startpage) Text("als Seite beim Öffnen ausgewählt"), ...data.children!.map((c) => genLT(c, true, hidden)).where((lt) => lt != null).toList().cast()],
                  ) : startpage ? Text("als Seite beim Öffnen ausgewählt") : null,
                  isThreeLine: data.children?.isNotEmpty == true,
                );
              }
              final lt = genLT(dest, false, false);
              return lt;
            }).where((lt) => lt != null).toList().cast(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Fertig"))
      ],
    );
  }
}

/// Prefs aus externer Datei laden
Future<String> loadFromExportJson(BuildContext context) async {
  final prefs = Provider.of<Preferences>(context, listen: false);
  final sie = prefs.preferredPronoun == Pronoun.sie;
  /// Datei-Auswahldialog
  FilePickerResult? result = await FilePicker.platform.pickFiles();
  /// Prüft, ob eine Datei ausgewählt wurde
  if (result != null) {
    File file = File(result.files.single.path!);
    try {
      var importJsonText = (await file.readAsString());
      var importJson = jsonDecode(importJsonText);
      if (importJson['prefs_version'] != prefsVersion) {
        bool? abort = showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
              title: const Text("Achtung!"),
              content: Text("Die Version dieser App stimmt nicht mit der Version der App überein, von der diese Datei erstellt wurde. ${sie ? "Bitte aktualisieren Sie": "Bitte aktualisiere"} beide Apps und ${sie ? "versuchen Sie" : "versuche"} es erneut. Das Fortfahren kann zu Fehlern führen und ${sie ? "Sie sollten dies nur benutzen, wenn Sie wissen, was Sie tun!": "Du solltest dies nur benutzen, wenn Du weißt, was du tust!"}"),
              actions: [
                TextButton(
                  child: const Text("Trotzdem fortfahren"),
                  onPressed: () => Navigator.pop(context, false),
                ),
                TextButton(
                  child: const Text("Abbrechen"),
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                ),
              ]
          ),
        ) as bool?;
        if (abort == null) return "abort";
        if (abort) return "abort";
      }
      prefs.loadFromJson(importJson["prefs_json"].toString());
      return "success";
    } catch (e, s) {
      logCatch("prefs_import", e, s);
      return "import_error";
    }
  } else {
    return "abort";
  }
}

Widget Function(BuildContext) sharePreferencesPageBuilder() => (context) => SharePreferencesPage();
class SharePreferencesPage extends StatefulWidget {
  const SharePreferencesPage({super.key});

  @override
  State<SharePreferencesPage> createState() => _SharePreferencesPageState();
}

class _SharePreferencesPageState extends State<SharePreferencesPage> {
  @override
  Widget build(BuildContext context) {
    final prefs = Provider.of<Preferences>(globalScaffoldContext, listen: false);
    String prefsJson = prefs.serialize();
    var exportJsonText = {
      'prefs_version': prefsVersion,
      'prefs_json': prefsJson,
    };
    var exportJson = jsonEncode(exportJsonText);
    return Scaffold(
      appBar: AppBar(title: const Text("Gespeicherte Einstellungen")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              final date = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}_${DateTime.now().hour}-${DateTime.now().minute}";
              Share.shareXFiles([XFile.fromData(utf8.encode(exportJson.toString()),mimeType: 'application/json')], fileNameOverrides: ['Kepler_App_Einstellungen_Export_$date.json'],
                sharePositionOrigin: Rect.fromLTWH(
                  0, 0,
                  MediaQuery.of(this.context).size.width,
                  MediaQuery.of(this.context).size.height / 2
                )
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(flex: 0, child: Text("Exportieren")),
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.ios_share, size: 16),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  //child: Text(widget.data + (sharedPreferences.getString(prefsPrefKey) as String)),
                  child: Text(exportJsonText.toString()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}