import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';

class NavEntryData {
  final Widget icon;
  final Widget? selectedIcon;
  final Widget label;
  final List<NavEntryData>? children;

  bool get isParent => children != null ? children!.isNotEmpty : false;

  const NavEntryData({required this.icon, this.selectedIcon, required this.label, this.children});
}

class NavEntry extends StatefulWidget {
  final Widget icon;
  final Widget? selectedIcon;
  final Widget label;
  final bool selected;
  final bool parentOfSelected;
  final int index;
  final int layer;
  final void Function() onSelect;
  final List<NavEntry>? children;

  bool get isParent => children != null ? children!.isNotEmpty : false;

  const NavEntry({super.key, required this.icon, this.selectedIcon, required this.label, required this.selected, required this.onSelect, required this.index, required this.parentOfSelected, required this.layer, this.children});

  @override
  State<NavEntry> createState() => _NavEntryState();
}

class _NavEntryState extends State<NavEntry> {
  late bool expanded = widget.parentOfSelected || widget.selected;

  @override
  Widget build(BuildContext context) {
    final color = (widget.parentOfSelected) ? HSLColor.fromColor(keplerColorBlue).withLightness(1/3).toColor() : keplerColorBlue;
    return Padding(
      padding: (widget.layer == 0) ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5) : const EdgeInsets.only(top: 6),
      child: AnimatedSize(
        alignment: Alignment.topCenter,
        curve: Curves.easeInOut,
        duration: const Duration(milliseconds: 200),
        reverseDuration: const Duration(milliseconds: 100),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: ((widget.selected || widget.parentOfSelected) ? Colors.blue.shade900 : Colors.grey).withAlpha(40)
                ),
                borderRadius: const BorderRadius.all(Radius.circular(16))
              ),
              child: ListTile(
                leading: (widget.selected || widget.parentOfSelected) ? widget.selectedIcon ?? widget.icon : widget.icon,
                trailing: widget.isParent ? Transform.translate(
                  offset: const Offset(7.5, 0),
                  child: IconButton(
                    onPressed: () => setState(() {
                      expanded = !expanded;
                    }),
                    icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ),
                ) : null,
                title: Transform.translate(
                  offset: const Offset(-7.5, 0),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      fontWeight: (widget.selected) ? FontWeight.bold : null,
                      fontSize: 16
                    ),
                    child: widget.label
                  ),
                ),
                selected: widget.selected || widget.parentOfSelected,
                selectedColor: color,
                splashColor: (widget.selected || widget.parentOfSelected) ? color.withOpacity(0.5) : null,
                onTap: () {
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

class TheDrawer extends StatefulWidget {
  final String selectedIndex;
  final void Function(String index) onDestinationSelected;
  final List<NavEntryData> entries;
  final List<int>? dividers;
  const TheDrawer({super.key, required this.selectedIndex, required this.onDestinationSelected, required this.entries, this.dividers});

  @override
  State<TheDrawer> createState() => _TheDrawerState();
}

class _TheDrawerState extends State<TheDrawer> {
  List<String> getParentSelectionIndices(String selectedIndex) {
    final out = <String>[];
    final split = selectedIndex.split(".").map((e) => int.parse(e)).toList();
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

  Widget dataToEntry(NavEntryData entryData, int index, String selectedIndex, int layer, String parentIndex) {
    final selectionIndex = "${(parentIndex != '') ? '$parentIndex.' : ''}$index";
    // generate all possible selection indices for the parents of the current selection, check if this entry has one of them -> parent to a selected node gets parent selection mode
    final parentOfSelected = getParentSelectionIndices(selectedIndex).contains(selectionIndex);
    final selected = selectionIndex == selectedIndex;
    return NavEntry(
      icon: entryData.icon,
      selectedIcon: entryData.selectedIcon,
      label: entryData.label,
      parentOfSelected: parentOfSelected,
      selected: selected,
      onSelect: () {
        widget.onDestinationSelected(selectionIndex);
        if (!entryData.isParent) {
          Navigator.pop(context);
        }
      },
      index: index,
      layer: layer,
      children: entryData.children?.asMap().map((i, e) => MapEntry(i, dataToEntry(e, i, selectedIndex, layer + 1, selectionIndex))).values.toList().cast(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries.asMap().map((i, entry) => MapEntry(i, dataToEntry(entry, i, widget.selectedIndex, 0, ""))).values.toList().cast<Widget>();
    widget.dividers?.forEach((divI) => entries.insert(divI, const Divider()));
    return Drawer(
      child: ListView(
        shrinkWrap: true,
        scrollDirection: Axis.vertical,
        children: [
          const DrawerHeader(child: Text("Kepler-App")),
          ...entries,
          const Padding(padding: EdgeInsets.all(4))
        ],
        // children: [
        //   const DrawerHeader(child: Text("Kepler-App")),
        //   ListView(
        //     shrinkWrap: true,
        //     children: entries,
        //   ),
        // ],
      ),
    );
  }
}
