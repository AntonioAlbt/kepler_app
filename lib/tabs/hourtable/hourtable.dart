import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:provider/provider.dart';

class HourtableTab extends StatefulWidget {
  const HourtableTab({super.key});

  @override
  State<HourtableTab> createState() => _HourtableTabState();
}

enum HTNavState { overview, yourPlan, classPlan, allReplaces, freeRooms }

class _HourtableTabState extends State<HourtableTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, w) {
        final navState = HTNavState.values[state.selectedNavigationIndex.last + (state.selectedNavigationIndex.length > 1 ? 1 : -2)];
        return Center(
          child: Text("Ausgewählt: $navState"),
        );
      },
    );
  }
}
