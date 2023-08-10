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
        final navState = state.selectedNavPageIDs.last;
        return Center(
          child: Text("Ausgewählt: $navState"),
        );
      },
    );
  }
}
