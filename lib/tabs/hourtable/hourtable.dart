import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
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
        if (shouldShowStuPlanIntro(stdata)) {
          return Column(
            children: [
              const Text("Es fehlen Daten. Bitte jetzt im Einführungsbildschirm ausfüllen."),
              ElevatedButton(
                onPressed: () {
                  state.selectedNavPageIDs = [PageIDs.home];
                  stuPlanOnTryOpenCallback(context);
                },
                child: const Text("Jetzt öffnen und ausfüllen"),
              ),
            ],
          );
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
  }
}

bool shouldShowStuPlanIntro(StuPlanData data) =>
    data.selectedClassName == null && data.selectedCourseIDs.isEmpty;

// returns true if all data is given and the stuplan page should be shown
// and false if the intro screens have to be shown
bool stuPlanOnTryOpenCallback(BuildContext context) {
  final state = Provider.of<AppState>(context, listen: false);
  final stdata = Provider.of<StuPlanData>(context, listen: false);
  if (!shouldShowStuPlanIntro(stdata)) return true;
  state.infoScreen ??= (state.userType != UserType.teacher)
      ? stuPlanPupilIntroScreens()
      : stuPlanTeacherIntroScreens();
  return false;
}
