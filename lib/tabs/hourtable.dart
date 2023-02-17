import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:provider/provider.dart';

class HourtableTab extends StatefulWidget {
  const HourtableTab({super.key});

  @override
  State<HourtableTab> createState() => _HourtableTabState();
}

class _HourtableTabState extends State<HourtableTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, w) {
        return Center(
          child: Text("Ausgewählt: ${(state.selectedNavigationIndex.length > 1) ? ["Dein Vertretungsplan", "Klassenplan", "Freie Zimmer"][state.selectedNavigationIndex.last] : "Übersicht für Vertretungsplan"}"),
        );
      },
    );
  }
}
