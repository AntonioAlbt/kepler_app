import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:provider/provider.dart';

class NavEntryData {
  final String id;
  final Widget icon;
  final Widget? selectedIcon;
  final Widget label;
  final List<NavEntryData>? children;
  final bool Function(BuildContext context)? isVisible;
  final List<UserType>? visibleFor;
  final bool? externalLink;
  /// can also be used as "onTap", true or null means open new page, false means don't open new page
  final bool Function(BuildContext context)? onTryOpen;
  /// can also be used as "onTap" for expand arrow, true or null means expand children list, false means don't
  final bool Function(BuildContext context)? onTryExpand;
  final List<String>? redirectTo;
  final List<Widget>? navbarActions;

  bool get isParent => children != null ? children!.isNotEmpty : false;
  bool shouldBeVisible(BuildContext ctx, UserType type) => (isVisible?.call(ctx) ?? true) && (visibleFor?.contains(type) ?? true);

  const NavEntryData({required this.id, required this.icon, this.selectedIcon, required this.label, this.children, this.isVisible, this.visibleFor, this.externalLink, this.onTryOpen, this.onTryExpand, this.redirectTo, this.navbarActions});
}

class NavEntry extends StatefulWidget {
  final String id;
  final Widget icon;
  final Widget? selectedIcon;
  final Widget label;
  final bool? externalLink;
  final bool Function(BuildContext context)? onTryOpen;
  final bool Function(BuildContext context)? onTryExpand;
  final bool selected;
  final bool parentOfSelected;
  final int layer;
  final void Function() onSelect;
  final List<NavEntry>? children;

  bool get isParent => children != null ? children!.isNotEmpty : false;

  const NavEntry({super.key, required this.id, required this.icon, this.selectedIcon, required this.label, required this.selected, required this.onSelect, required this.parentOfSelected, required this.layer, this.children, this.externalLink, this.onTryOpen, this.onTryExpand});

  @override
  State<NavEntry> createState() => _NavEntryState();
}

const expandDuration = 200;
const reverseExpandDuration = 100;

class _NavEntryState extends State<NavEntry> {
  late bool expanded = widget.parentOfSelected || widget.selected;

  @override
  Widget build(BuildContext context) {
    final color = (widget.parentOfSelected) ? colorWithLightness(keplerColorBlue, 1/3) : keplerColorBlue;
    return Padding(
      padding: (widget.layer == 0) ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5) : const EdgeInsets.only(top: 6),
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
                  color: ((widget.selected || widget.parentOfSelected) ? Colors.blue.shade900 : Colors.grey).withAlpha(40)
                ),
                borderRadius: const BorderRadius.all(Radius.circular(16))
              ),
              child: ListTile(
                leading: (widget.selected || widget.parentOfSelected) ? widget.selectedIcon ?? widget.icon : widget.icon,
                trailing: widget.isParent ? Transform.translate(
                  offset: const Offset(7.5, 0),
                  child: IconButton(
                    onPressed: () {
                      if (!expanded) {
                        if (widget.onTryExpand?.call(context) == false) return;
                      }
                      setState(() => expanded = !expanded);
                      _drawerKey.currentState?.redraw();
                    },
                    icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ),
                ) : null,
                title: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontWeight: (widget.selected) ? FontWeight.bold : null,
                    fontSize: 16,
                  ),
                  child: Row(
                    children: [
                      widget.label,
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
                  if (widget.onTryOpen?.call(context) == false) return;
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
  final _controller = ScrollController();

  void redraw() async {
    await Future.delayed(const Duration(milliseconds: expandDuration + 5));
    // await _controller.animateTo(_controller.offset + .001, duration: const Duration(milliseconds: expandDuration + 5), curve: Curves.easeInBack);
    // _controller.jumpTo(_controller.position - .5);
    _controller.jumpTo(_controller.offset + .001);
    // await Future.delayed(const Duration(milliseconds: 50));
    // _controller.animateTo(_controller.offset - .5, duration: const Duration(milliseconds: 1), curve: Curves.linear);
  }

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

  Widget dataToEntry(NavEntryData entryData, String selectedIndex, int layer, String parentIndex, UserType role) {
    final selectionIndex = "${(parentIndex != '') ? '$parentIndex.' : ''}${entryData.id}";
    // generate all possible selection indices for the parents of the current selection, check if this entry has one of them -> parent to a selected node gets parent selection mode
    final parentOfSelected = getParentSelectionIndices(selectedIndex).contains(selectionIndex);
    final selected = selectionIndex == selectedIndex;
    return NavEntry(
      id: entryData.id,
      icon: entryData.icon,
      selectedIcon: entryData.selectedIcon,
      label: entryData.label,
      externalLink: entryData.externalLink,
      parentOfSelected: parentOfSelected,
      selected: selected,
      onSelect: () {
        widget.onDestinationSelected(entryData.redirectTo?.join(".") ?? selectionIndex);
        if (!entryData.isParent) {
          Navigator.pop(context);
        }
      },
      onTryOpen: entryData.onTryOpen,
      onTryExpand: entryData.onTryExpand,
      layer: layer,
      children: entryData.children
          ?.map((data) => (data.shouldBeVisible(
                  context, Provider.of<AppState>(context).userType))
              ? dataToEntry(
                  data, selectedIndex, layer + 1, selectionIndex, role)
              : null,
          ).where((element) => element != null)
          .toList()
          .cast(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userType = Provider.of<AppState>(context, listen: false).userType;
    final entries = widget.entries.asMap().map((i, entry) => MapEntry(i, dataToEntry(entry, widget.selectedIndex, 0, "", userType))).values.toList().cast<Widget>();
    widget.dividers?.forEach((divI) => entries.insert(divI, const Divider()));
    return Drawer(
      child: ListView(
        controller: _controller,
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
