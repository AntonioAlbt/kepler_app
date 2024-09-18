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

import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:provider/provider.dart';


/// InfoScreen-s dienen zur Anzeige von Infos in einem Overlay über die Haupt-Appoberfläche.
/// Dabei werden sie mit einem Stack immer darüber angezeigt.
/// vor allem genutzt für: Einleitungsdialoge, Mail-Ansicht, Stundenplan-Einrichtung
/// (wenn volle Aufmerksamkeit des Benutzers auf einen Vorgang gelenkt werden soll,
/// welcher mehrere Schritte zum Abschließen benötigt -> "Fortschritt" wird mit Punkten angezeigt)
class InfoScreen extends StatefulWidget {
  /// empfohlen: Icon - wird als großes Bild über anderen Texten angezeigt
  final Widget? infoImage;
  /// empfohlen: Text - Titel, wird als größerer Text (automatisch formatiert) über Haupttext angezeigt
  final Widget? infoTitle;
  /// empfohlen: beliebiges Widget oder Text - Hauptelement, entspricht body eines Dialogs
  final Widget? infoText;
  /// Verwendung nicht empfohlen - falls gesetzt, werden alle anderen Widgets ignoriert und nur dieses angezeigt
  final Widget? customScreen;

  /// ob der Benutzer selbst den InfoScreen schließen kann
  final bool closeable;
  /// wird aufgerufen, wenn der Benutzer durch Auslösen von "Zurück" oder durch Tippen vom Schließen-Knopf versucht,
  /// den InfoScreen zu schließen
  final bool Function(int index, BuildContext ctx)? onTryClose;

  const InfoScreen({super.key, this.infoImage, this.infoTitle, this.infoText, this.customScreen, this.closeable = true, this.onTryClose});

  @override
  State<InfoScreen> createState() => InfoScreenState();
}

class InfoScreenState extends State<InfoScreen> {
  @override
  Widget build(BuildContext context) {
    /// customScreen überschreibt alles
    if (widget.customScreen != null) return widget.customScreen!;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.infoImage != null) Padding(
              padding: const EdgeInsets.all(8.0),
              child: widget.infoImage!,
            ),
            /// automatische Formatiertung mit DefaultTextStyle
            if (widget.infoTitle != null) DefaultTextStyle(
              style: Theme.of(context).textTheme.headlineSmall!,
              textAlign: TextAlign.center,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: widget.infoTitle!,
              ),
            ),
            if (widget.infoText != null) Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyLarge!,
                textAlign: TextAlign.center,
                child: widget.infoText!,
              ),
            ),
            if (widget.infoText == null && widget.infoTitle == null && widget.infoImage == null) const Padding(
              padding: EdgeInsets.all(8),
              child: Text("Keine Daten."),
            )
          ],
        ),
      ),
    );
  }
}

/// damit der InfoScreen von überall weitergeblättert werden kann, muss von überall auf den State zugegriffen
/// werden können - da es nur ein InfoScreenDisplay Widget je geben sollte, kann dafür ein GlobalKey verwendet werden
final infoScreenKey = GlobalKey<InfoScreenDisplayState>();
InfoScreenDisplayState get infoScreenState => infoScreenKey.currentState!;

/// kümmert sich um die Organisation und Anzeige von mehreren InfoScreens
class InfoScreenDisplay extends StatefulWidget {
  final List<InfoScreen> infoScreens;
  /// kontrolliert, ob der Benutzer händisch zwischen den InfoScreens horizontal scrollen kann
  final bool scrollable;
  /// wird nach Öffnen aufgerufen, damit direkt etwas mit dem State gemacht werden kann
  /// - wird aber anscheinend nirgendwo verwendet - hab ich mal wieder top organisiert :|
  final void Function(InfoScreenDisplayState state)? openedCallback;

  InfoScreenDisplay({required this.infoScreens, this.scrollable = false, this.openedCallback}): super(key: infoScreenKey);

  @override
  State<InfoScreenDisplay> createState() => InfoScreenDisplayState();
}

int roundNumberAway(double number, double other) {
  if (number < other) {
    return number.floor();
  } else if (number > other) {
    return number.ceil();
  } else {
    return number.round();
  }
}

// rounds a number away if its fractional part is further away from the number than tolerance, otherwise rounds it normally
int roundNumberAwayWithTolerance(double number, double awayFrom, double tolerance) {
  if (number % 1 <= tolerance || (1 - number % 1) <= tolerance) return number.round();
  return roundNumberAway(number, awayFrom);
}

class InfoScreenDisplayState extends State<InfoScreenDisplay> with SingleTickerProviderStateMixin {
  late final List<InfoScreen> infoScreens;
  late TabController _controller;

  /// falls der Benutzer nur ein wenig weiterscrollt, wird die Animation schon leicht aktualisiert, aber der
  /// echte Auswahlindex (_controller.index) wird erst bei komplettem Abschluss des Weiterscrollens von Flutter
  /// aktualisiert -
  /// da ich aber für die Punkte den Punkt für den aktuell am meisten/ehesten sichtbaren InfoScreen hervorheben
  /// will, kann mit nextOrCurrentIndex der Einfachheit halber der aktuell eher richtige Index genommen werden
  int get nextOrCurrentIndex => roundNumberAwayWithTolerance(_controller.animation!.value, _controller.index.toDouble(), 0.1);
  int get index => _controller.index;
  /// Hilfsfunktionen, damit der Code schöner aussieht (haha)
  void animateTo(int index) => _controller.animateTo(index);
  void next() => animateTo(index + 1);
  void previous() => animateTo(index - 1);

  /// siehe Name - falls der aktuelle InfoScreen nicht schließbar ist, wird je nach Animationswert noch
  /// der Nächste überprüft
  bool canCloseCurrentScreen() {
    if (!infoScreens[_controller.index].closeable) return infoScreens[_controller.animation!.value.round()].closeable;
    return infoScreens[nextOrCurrentIndex].closeable;
  }

  /// da InfoScreens selbst entscheiden können, ob etwas passieren soll, wenn der Benutzer versucht
  /// muss zum schließen erst die entsprechende Funktion aufgerufen werden
  bool tryCloseCurrentScreen() => canCloseCurrentScreen() && (infoScreens[nextOrCurrentIndex].onTryClose?.call(nextOrCurrentIndex, context) ?? true);

  /// wird nicht verwendet? keine Ahnung, warum ich die nie gebraucht habe, anscheinend muss der TabController
  /// doch nicht aktualisiert werden
  /// -- die Liste der InfoScreens kann nur verändert werden, indem ein neues InfoScreenDisplay im AppState gesetzt wird
  // void updateInfoScreens(List<InfoScreen> updatedInfoScreens) {
  //   _controller.dispose();
  //   setState(() {
  //     infoScreens = updatedInfoScreens;
  //     _controller = TabController(length: updatedInfoScreens.length, vsync: this);
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 100),
          child: Scaffold(
            key: const Key("1"),
            body: Container(
              padding: MediaQuery.of(context).padding,
              color: Theme.of(context).colorScheme.surface,
              child: Stack(
                children: [
                  TabBarView(
                    controller: _controller,
                    physics: (!widget.scrollable) ? const NeverScrollableScrollPhysics() : null,
                    children: infoScreens,
                  ),
                  if (kDebugFeatures) Align(
                    alignment: Alignment.topRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          onPressed: () => infoScreenState.previous(),
                          backgroundColor: Colors.red.shade800,
                          heroTag: UniqueKey(),
                          child: const Icon(Icons.arrow_back),
                        ),
                        FloatingActionButton.small(
                          onPressed: () => infoScreenState.next(),
                          backgroundColor: Colors.red.shade800,
                          heroTag: UniqueKey(),
                          child: const Icon(Icons.arrow_forward),
                        ),
                      ],
                    ),
                  ),
                  /// length > 1 bedeutet, dass die Fortschritts-Punkte angezeigt werden -
                  /// und die werden hier ausgeblendet, wenn die Tastatur aktuell verwendet wird
                  if (infoScreens.length > 1) KeyboardVisibilityBuilder(
                    builder: (context, keyboardVisible) {
                      if (keyboardVisible) return const SizedBox.shrink();
                      final dark = hasDarkTheme(context);
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                              borderRadius: const BorderRadius.all(Radius.circular(8))
                            ),
                            child: AnimatedBuilder(
                              animation: _controller.animation!,
                              builder: (context, _) => Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                /// Liste mit Punkten wird dynamisch abhängig von Anzahl InfoScreens generiert
                                children: List.generate(
                                  infoScreens.length,
                                  (i) => GestureDetector(
                                    // onTap: () => _controller.animateTo(i),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: (_controller.animation!.value.round() == i) ? Colors.grey[(dark) ? 200 : 800] : Colors.grey[(dark) ? 600 : 400],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  ),
                  /// AnimatedBuilder sorgt für smoothe Überblendungen zwischen InfoScreens mit Fading
                  AnimatedBuilder(
                    animation: _controller.animation!,
                    builder: (context, _) => AnimatedOpacity(
                      duration: const Duration(milliseconds: 100),
                      opacity: canCloseCurrentScreen() ? 1 : 0,
                      /// falls der aktuelle InfoScreen nicht schließbar ist, werden Eingaben auf diesen Knopf
                      /// ignoriert (und der Knopf wird 100 % durchsichtig gemacht)
                      child: IgnorePointer(
                        ignoring: !canCloseCurrentScreen(),
                        child: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                // gradient: RadialGradient(colors: [Theme.of(context).colorScheme.background, Theme.of(context).colorScheme.background.withAlpha(0)], stops: const [0.9, 1]),
                                border: Border.all(color: Theme.of(context).highlightColor, width: 1.5),
                                color: Theme.of(context).colorScheme.surface.withOpacity(0.5)
                              ),
                              child: IconButton(
                                padding: const EdgeInsets.all(5),
                                visualDensity: const VisualDensity(horizontal: -2.0, vertical: -1.5),
                                onPressed: () {
                                  if (tryCloseCurrentScreen()) state.clearInfoScreen();
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        );
      },
    );
  }

  @override
  void initState() {
    infoScreens = widget.infoScreens;
    _controller = TabController(length: infoScreens.length, vsync: this);
    if (widget.openedCallback != null) widget.openedCallback?.call(this);
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
