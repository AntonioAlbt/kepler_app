import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:kepler_app/tabs/hourtable/pages/all_replaces.dart';
import 'package:kepler_app/tabs/hourtable/pages/class_plan.dart';
import 'package:kepler_app/tabs/hourtable/pages/free_rooms.dart';
import 'package:kepler_app/tabs/hourtable/pages/room_plan.dart';
import 'package:kepler_app/tabs/hourtable/pages/teacher_plan.dart';
import 'package:kepler_app/tabs/hourtable/pages/your_plan.dart';
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
        if (shouldShowStuPlanIntro(stdata, state.userType == UserType.teacher)) {
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
        final navPage = state.selectedNavPageIDs.last;
        if (navPage == StuPlanPageIDs.yours) return const YourPlanPage();
        if (navPage == StuPlanPageIDs.classPlans) return const ClassPlanPage();
        if (navPage == StuPlanPageIDs.all) return const AllReplacesPage();
        if (navPage == StuPlanPageIDs.freeRooms) return const FreeRoomsPage();
        if (navPage == StuPlanPageIDs.teacherPlan) {
          if (state.userType == UserType.teacher) {
            return const TeacherPlanPage();
          } else {
            return const Text("Halt Stopp! Nur für Lehrer.");
          }
        }
        if (navPage == StuPlanPageIDs.roomPlans) return const RoomPlanPage();
        return const Text("Unbekannter Plan gefordert. Bitte schließen und erneut probieren.");
      },
    );
  }

  @override
  void initState() {
    super.initState();
  }
}

bool shouldShowStuPlanIntro(StuPlanData data, bool teacher) =>
    teacher ? (data.selectedTeacherName == null) : (data.selectedClassName == null || data.selectedCourseIDs.isEmpty);

// returns true if all data is given and the stuplan page should be shown
// and false if the intro screens have to be shown
Future<bool> stuPlanOnTryOpenCallback(BuildContext context) async {
  final state = Provider.of<AppState>(context, listen: false);
  final stdata = Provider.of<StuPlanData>(context, listen: false);
  if (!shouldShowStuPlanIntro(stdata, state.userType == UserType.teacher)) {
    return true;
  }
  state.infoScreen ??= (state.userType != UserType.teacher)
      ? stuPlanPupilIntroScreens()
      : stuPlanTeacherIntroScreens();
  return false;
}
