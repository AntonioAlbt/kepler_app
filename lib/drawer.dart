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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class NavEntryData {
  /// eindeutige ID im Bezug auf andere NavEntrys auf gleichem Verschachtelungslevel
  final String id;
  /// Icon für den Drawer
  final Widget icon;
  /// Icon für den Drawer, wenn Eintrag ausgewählt ist
  final Widget? selectedIcon;
  /// Titel des Eintrages im Drawer
  final Widget label;
  /// Liste der Untereinträge
  final List<NavEntryData>? children;
  /// zur dynamischen Bestimmung, ob der Eintrag beim Rendern des Drawers mit angezeigt werden soll
  final bool Function(BuildContext context)? isVisible;
  /// Eintrag nur für diese Benutzertypen anzeigen
  final List<UserType>? visibleFor;
  /// zur dynamischen Bestimmung, ob der Eintrag beim Rendern des Drawers als gesperrt angezeigt werden soll
  final bool Function(BuildContext context)? isLocked;
  /// Eintrag für diese Benutzertypen als gesperrt anzeigen
  final List<UserType>? lockedFor;
  /// Icon anzeigen, was andeutet, dass Eintrag separat geöffnet wird
  final bool? externalLink;
  /// if false, will make it so on tap it only expands and can't be selected - only works if has children!
  final bool? selectable;
  /// can also be used as "onTap", true or null means open new page, false means don't open new page
  final Future<bool> Function(BuildContext context)? onTryOpen;
  /// wird aufgerufen, wenn versucht wird, die Kinder aufzublättern
  /// can also be used as "onTap" for expand arrow, true or null means expand children list, false means don't
  final Future<bool> Function(BuildContext context)? onTryExpand;
  /// welcher Navigationsindex beim Antippen und erfolgreichem Auswählen automatisch ausgewählt werden soll
  final List<String>? redirectTo;
  /// Liste der Aktions-Icons, die in der AppBar angezeigt werden sollen, wenn dieser Eintrag ausgewählt ist
  final List<Widget>? navbarActions;
  
  /// wird beim Rendern vom Drawer aufgerufen, zur dynamischen Erstellung der Untereinträge
  final List<NavEntryData> Function(BuildContext context)? childrenBuilder;

  // bool get isParent => children != null ? children!.isNotEmpty : false;
  /// Hilfsfunktionen für cleaneren Code
  bool isParent(BuildContext ctx) => getChildren(ctx).isNotEmpty;
  List<NavEntryData> getChildren(BuildContext ctx) {
    if (children != null && children!.isNotEmpty) {
      return children!;
    } else if (childrenBuilder != null) {
      final built = childrenBuilder!.call(ctx);
      if (built.isNotEmpty) return built;
    }

    return [];
  }
  bool shouldBeVisible(BuildContext ctx, UserType type) => (isVisible?.call(ctx) ?? true) && (visibleFor?.contains(type) ?? true);
  bool shouldBeLocked(BuildContext ctx, UserType type) => (isLocked?.call(ctx) ?? false) || (lockedFor?.contains(type) ?? false);

  const NavEntryData({
    required this.id,
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.children,
    this.isVisible,
    this.visibleFor,
    this.isLocked,
    this.lockedFor,
    this.externalLink,
    this.selectable,
    this.onTryOpen,
    this.onTryExpand,
    this.redirectTo,
    this.navbarActions,
    this.childrenBuilder,
  });
}

class NavEntry extends StatefulWidget {
  /// Werte für alle übereinstimmenden Argumente eigentlich direkt übernommen von NavEntryData

  final String id;
  final Widget icon;
  final Widget? selectedIcon;
  final Widget label;
  final bool? externalLink;
  final bool selectable;
  final Future<bool> Function(BuildContext context)? onTryOpen;
  final Future<bool> Function(BuildContext context)? onTryExpand;
  /// ob der Eintrag aktuell ausgewählt ist
  final bool selected;
  /// ob ein Untereintrag des aktuellen Eintrags ausgewählt ist
  final bool parentOfSelected;
  /// wie tief verschachtelt der Eintrag ist (Anzahl der Eltern-Einträge)
  final int layer;
  /// wird bei erfolgreichem Auswählen des Eintrages aufgerufen
  final void Function() onSelect;
  /// soll der Eintrag als gesperrt angezeigt werden
  final bool locked;
  /// welchen Benutzertyp muss der Benutzer "erreichen", damit der Eintrag entsperrt wird
  final List<UserType> unlockedFor;
  /// feste Liste der Untereinträge
  final List<Widget>? children;

  bool get isParent => children != null ? children!.isNotEmpty : false;

  const NavEntry({
    super.key,
    required this.id,
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.parentOfSelected,
    required this.layer,
    this.children,
    this.externalLink,
    this.selectable = true,
    this.onTryOpen,
    this.onTryExpand,
    required this.locked,
    required this.unlockedFor,
  });

  @override
  State<NavEntry> createState() => _NavEntryState();
}

/// Dauer für die entsprechende Animation für NavEntries, in ms
const expandDuration = 200;
const reverseExpandDuration = 100;

/// Hilfsfunktion, um Elemente in einer Liste zu verketten,
/// wobei die letzten zwei Elemente durch joinStrLast statt joinStr verbunden werden
/// - etwa für "1, 2, 3 und 4" statt nur "1, 2, 3, 4"
String joinWithOptions(List<dynamic> toJoin, String joinStr, String joinStrLast) {
  var out = "";
  for (var i = 0; i < toJoin.length; i++) {
    out += toJoin[i].toString() + ((i == toJoin.length - 1) ? "" : (i == toJoin.length - 2) ? joinStrLast : joinStr);
  }
  return out;
}

class _NavEntryState extends State<NavEntry> {
  // marked as late so widget can be used in the initializer
  late bool expanded = widget.parentOfSelected || widget.selected;

  @override
  Widget build(BuildContext context) {
    final color = (widget.parentOfSelected) ? colorWithLightness(keplerColorBlue, 1/3) : keplerColorBlue;
    /// Hilfsfunktion, damit noch `bool sie` abgefragt werden kann
    showLockedDialog() {
      final sie = Provider.of<Preferences>(context, listen: false).preferredPronoun == Pronoun.sie;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Zugriff nur mit Anmeldung"),
          content: Text("Um auf diese Funktion zuzugreifen, ${sie ? "melden Sie sich" : "melde Dich"} bitte als ${joinWithOptions(widget.unlockedFor, ", ", " oder ")} an."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showLoginScreenAgain(clearData: false);
              },
              child: const Text("Neu einloggen"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Abbrechen"),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: (widget.layer == 0) ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5) : const EdgeInsets.only(top: 6),
      /// wird verwendet, damit eine Art "Aufklappanimation" dargestellt wird - sieht zwar nicht so gut aus,
      /// weil die Elemente vorm vollständigen Aufklappen unten einfach abgeschnitten werden, aber besser als nichts
      child: AnimatedSize(
        alignment: Alignment.topCenter,
        curve: Curves.easeInOut,
        duration: const Duration(milliseconds: expandDuration),
        reverseDuration: const Duration(milliseconds: reverseExpandDuration),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  /// wenn widget ausgewählt oder Elternteil eines ausgewählten (beliebige Stufe) ist, dunkles Blau,
                  /// wenn gesperrt, grau (für "keine Interaktion möglich")
                  color: ((widget.selected || widget.parentOfSelected) ? Colors.blue.shade900 : (widget.locked) ? Colors.grey.shade700 : Colors.grey).withAlpha(40)
                ),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
              child: ListTile(
                leading: (widget.selected || widget.parentOfSelected) ? widget.selectedIcon ?? widget.icon : widget.icon,
                trailing: (widget.isParent || widget.locked) ? Transform.translate(
                  offset: const Offset(7.5, 0),
                  child: IconButton(
                    /// handler kümmert sich um gesperrt und ausklappen, da beides über diesen Icon-Button läuft
                    onPressed: () {
                      if (widget.locked) {
                        showLockedDialog();
                        return;
                      }
                      if (!expanded) {
                        final val = widget.onTryExpand?.call(context);
                        if (val != null) {
                          val.then((value) {
                            if (!value) return;
                            setState(() => expanded = !expanded);
                            _drawerKey.currentState?.redraw();
                          });
                          return;
                        }
                      }
                      setState(() => expanded = !expanded);
                      _drawerKey.currentState?.redraw();
                    },
                    icon: Icon(widget.locked ? Icons.lock : expanded ? Icons.expand_less : Icons.expand_more),
                  ),
                ) : null,
                /// DefaultTextStyle ändert den Style von Text-Widgets unter ihm, die selbst keinen TextStyle angeben
                title: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontWeight: (widget.selected) ? FontWeight.bold : null,
                    fontSize: 16,
                  ),
                  child: Row(
                    children: [
                      Flexible(child: widget.label),
                      if (widget.externalLink == true) const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.open_in_new, size: 18),
                      ),
                    ],
                  ),
                ),
                selected: widget.selected || widget.parentOfSelected,
                selectedColor: color,
                splashColor: (widget.selected || widget.parentOfSelected) ? color.withOpacity(0.5) : null,
                onTap: () {
                  if (widget.locked) {
                    showLockedDialog();
                    return;
                  }

                  if (!widget.selectable && widget.isParent) { 
                    if (!expanded) {
                      final val = widget.onTryExpand?.call(context);
                      if (val != null) {
                        val.then((value) {
                          if (!value) return;
                          setState(() => expanded = !expanded);
                          _drawerKey.currentState?.redraw();
                        });
                        return;
                      }
                    }
                    setState(() => expanded = !expanded);
                    _drawerKey.currentState?.redraw();
                    return;
                  }

                  final val = widget.onTryOpen?.call(context);
                  if (val != null) {
                    val.then((value) {
                      if (!value) return;
                      setState(() {
                        expanded = true;
                      });
                      widget.onSelect();
                    });
                    return;
                  }
                  setState(() {
                    expanded = true;
                  });
                  widget.onSelect();
                },
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                selectedTileColor: (widget.parentOfSelected) ? color.withAlpha(10) : color.withAlpha(40),
                // tileColor: Theme.of(context).highlightColor.withAlpha(20),
                visualDensity: const VisualDensity(
                  vertical: -.5,
                  horizontal: -4
                ),
              ),
            ),
            if (widget.isParent && expanded) Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                children: widget.children!,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// nur in dieser Datei benötigt (deshalb privat -> "_") um Drawer nach Auswahländerung neu zu zeichnen
/// (siehe _TheDrawerState.redraw())
final _drawerKey = GlobalKey<_TheDrawerState>();

class TheDrawer extends StatefulWidget {
  final String selectedIndex;
  final void Function(String index) onDestinationSelected;
  final List<NavEntryData> entries;
  final List<int>? dividers;
  TheDrawer({required this.selectedIndex, required this.onDestinationSelected, required this.entries, this.dividers}) : super(key: _drawerKey);

  @override
  State<TheDrawer> createState() => _TheDrawerState();
}

class _TheDrawerState extends State<TheDrawer> {
  final _controller = AutoScrollController();
  /// für eindeutige IDs, da für scroll_to_index jeder Eintrag einen eindeutigen Index benötigt
  final _idMap = <String, int>{};
  int _lastId = 0;

  void redraw() async {
    await Future.delayed(const Duration(milliseconds: expandDuration + 5));
    // await _controller.animateTo(_controller.offset + .001, duration: const Duration(milliseconds: expandDuration + 5), curve: Curves.easeInBack);
    // _controller.jumpTo(_controller.position - .5);
    _controller.jumpTo(_controller.offset + .001);
    // await Future.delayed(const Duration(milliseconds: 50));
    // _controller.animateTo(_controller.offset - .5, duration: const Duration(milliseconds: 1), curve: Curves.linear);
  }

  /// vollständige Indices der Elternteile über dem entsprechenden Index bestimmen
  /// z.B. für "lernsax.lslogin:abc.notifications" -> ["lernsax", "lernsax.lslogin:abc"]
  List<String> getParentSelectionIndices(String selectedIndex) {
    final out = <String>[];
    final split = selectedIndex.split(".").toList();
    for (var i = 0; i < split.length; i++) {
      var currentParentStr = "";
      for (var j = 0; j <= i; j++) {
        currentParentStr += "${split[j]}.";
      }
      out.add(currentParentStr.substring(0, currentParentStr.length - 1)); // cut off last char -> remove last "."
    }
    out.remove(selectedIndex);
    return out;
  }

  /// baut einen NavEntry aus NavEntryData
  /// - beachtet nicht, ob NavEntry für Benutzer sichtbar sein soll!
  Widget dataToEntry(NavEntryData entryData, String selectedIndex, int layer, String parentIndex, UserType userType) {
    final selectionIndex = "${(parentIndex != '') ? '$parentIndex.' : ''}${entryData.id}";
    // generate all possible selection indices for the parents of the current selection, check if this entry has one of them -> parent to a selected node gets parent selection mode
    final parentOfSelected = getParentSelectionIndices(selectedIndex).contains(selectionIndex);
    final selected = selectionIndex == selectedIndex;
    _lastId++;
    /// einmaliger Index für scroll_to_index
    _idMap[selectionIndex] = _lastId;
    /// AutoScrollTag, damit dann mit scroll_to_index automatisch zum aktuell ausgewählten Eintrag gescrollt werden kann
    return AutoScrollTag(
      controller: _controller,
      index: _idMap[selectionIndex]!,
      key: ValueKey(selectionIndex),
      child: NavEntry(
        id: entryData.id,
        icon: entryData.icon,
        selectedIcon: entryData.selectedIcon,
        label: entryData.label,
        externalLink: entryData.externalLink,
        selectable: entryData.selectable ?? true,
        parentOfSelected: parentOfSelected,
        selected: selected,
        onSelect: () {
          widget.onDestinationSelected(entryData.redirectTo?.join(".") ?? selectionIndex);
          /// Drawer wird automatisch geschlossen, wenn ein Eintrag ohne Kinder ausgewählt wird
          if (!entryData.isParent(context)) {
            Navigator.pop(context);
          }
        },
        onTryOpen: entryData.onTryOpen,
        onTryExpand: entryData.onTryExpand,
        layer: layer,
        locked: entryData.shouldBeLocked(context, userType),
        unlockedFor: UserType.values.where((val) => entryData.lockedFor?.contains(val) != true).toList(),
        /// Kinder nur hinzufügen, wenn sie auch für den Benutzer sichtbar sind
        children: entryData.getChildren(context)
            ?.map((data) => (data.shouldBeVisible(context, userType))
                ? dataToEntry(data, selectedIndex, layer + 1, selectionIndex, userType)
                : null,
            ).where((element) => element != null)
            .toList().cast(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userType = Provider.of<AppState>(context, listen: false).userType;
    /// da dataToEntry nicht berücksichtigt, ob der Benutzer den NavEntry sehen kann, werden unsichtbare vorher
    /// rausgefiltert
    final entries = widget.entries.where((e) => e.shouldBeVisible(context, userType)).toList().asMap()
      .map((i, entry) => MapEntry(i, dataToEntry(entry, widget.selectedIndex, 0, "", userType))).values
      .toList().cast<Widget>();
    /// bei jedem dividerIndex einen Divider einfügen
    widget.dividers?.forEach((divI) => entries.insert(divI, const Divider()));
    return Drawer(
      child: ListView(
        controller: _controller,
        shrinkWrap: true,
        scrollDirection: Axis.vertical,
        children: [
          /// Kepler-Logo mit Text "Kepler-App" als Kopf
          DrawerHeader(
            child: Row(
              children: [
                Flexible(
                  child: Image.asset("assets/JKGLogo.png"),
                ),
                const Center(
                  child: SizedBox(
                    width: 120,
                    child: Text(
                      "Kepler-\nApp",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...entries,
          /// nötig, da sonst der letzte Eintrag mit Bildschirmkante unten abschließt
          const Padding(padding: EdgeInsets.all(4))
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    /// nach rendern des Frames automatisch zum aktuell ausgewählten Eintrag scrollen
    /// muss bis nach Frame warten, da sonst _controller.animation.value zu zeitig verändert wird
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = _idMap[Provider.of<AppState>(context, listen: false).selectedNavPageIDs.join(".")];
      /// id sollte nie null sein, aber ist jetzt nicht so schlimm wenn nicht gescrollt wird
      if (id != null) _controller.scrollToIndex(id, duration: const Duration(milliseconds: 1), preferPosition: AutoScrollPosition.middle);
    });
  }
}
