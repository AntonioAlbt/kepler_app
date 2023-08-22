import 'package:flutter/material.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';

class AllReplacesPage extends StatelessWidget {
  const AllReplacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: StuPlanDisplay(
        className: "5 bis 12",
        allReplacesMode: true,
        showInfo: false,
      ),
    );
  }
}
