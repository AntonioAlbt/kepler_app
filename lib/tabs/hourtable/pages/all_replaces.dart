import 'package:flutter/material.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';

final allReplacesDisplayKey = GlobalKey<StuPlanDisplayState>();

class AllReplacesPage extends StatelessWidget {
  const AllReplacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: StuPlanDisplay(
        key: allReplacesDisplayKey,
        selected: "5 bis 12",
        mode: SPDisplayMode.allReplaces,
        showInfo: false,
      ),
    );
  }
}

void allReplacesRefreshAction() {
  allReplacesDisplayKey.currentState?.forceRefreshData();
}
