import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';
import 'package:provider/provider.dart';

const bool showSTDebugStuff = kDebugMode;

final yourPlanDisplayKey = GlobalKey<StuPlanDisplayState>();

class YourPlanPage extends StatelessWidget {
  const YourPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stdata = Provider.of<StuPlanData>(context);
    return Column(
      children: [
        Flexible(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: StuPlanDisplay(
              key: yourPlanDisplayKey,
              className: stdata.selectedClassName!,
            ),
          ),
        ),
        if (showSTDebugStuff) ElevatedButton(
          onPressed: () {
            stdata.selectedClassName = null;
            stdata.selectedCourseIDs = [];
          },
          child: const Text("reset"),
        ),
      ],
    );
  }
}

void yourStuPlanEditAction() {
  final state = Provider.of<AppState>(globalScaffoldKey.currentContext!, listen: false);
  state.infoScreen ??= (state.userType != UserType.teacher)
      ? stuPlanPupilIntroScreens()
      : stuPlanTeacherIntroScreens();
}

void yourStuPlanRefreshAction() {
  yourPlanDisplayKey.currentState?.forceRefreshData();
}
