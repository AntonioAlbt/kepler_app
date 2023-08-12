import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:provider/provider.dart';

class HourtableTab extends StatefulWidget {
  const HourtableTab({super.key});

  @override
  State<HourtableTab> createState() => _HourtableTabState();
}

class _HourtableTabState extends State<HourtableTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AppState, StuPlanData>(
      builder: (context, state, stdata, _) {
        if (stdata.selectedClassName == null) {
          return const Text("Gerade im Auswahl-Bildschirm.");
        }
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(stdata.selectedClassName ?? "un"),
              TextButton(onPressed: () => stdata.selectedClassName = null, child: const Text("reset")),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (Provider.of<StuPlanData>(context, listen: false).selectedClassName == null) {
      // because you can't update the state while this.build() is consuming it,
      // we wait for after the current render to update it (show a infoScreen)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final state = Provider.of<AppState>(context, listen: false);
        final stdata = Provider.of<StuPlanData>(context, listen: false);
        if (stdata.selectedClassName != null && stdata.selectedCourseIDs.isNotEmpty) return;
        state.infoScreen ??= (state.userType != UserType.teacher)
            ? stuPlanPupilIntroScreens()
            : stuPlanTeacherIntroScreens();
      });
    }
  }
}
