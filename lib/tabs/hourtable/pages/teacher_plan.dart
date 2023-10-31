import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';
import 'package:provider/provider.dart';

class TeacherPlanPage extends StatefulWidget {
  const TeacherPlanPage({super.key});

  @override
  State<TeacherPlanPage> createState() => _TeacherPlanPageState();
}

class _TeacherPlanPageState extends State<TeacherPlanPage> {
  late String selectedTeacher;

  @override
  Widget build(BuildContext context) {
    return Consumer<StuPlanData>(
      builder: (context, stdata, _) => Column(
        children: [
          SizedBox(
            height: 50,
            child: AppBar(
              scrolledUnderElevation: 5,
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              elevation: 5,
              bottom: PreferredSize(
                preferredSize: const Size(100, 50),
                child: DropdownButton<String>(
                  items: stdata.availableTeachers!.map((e) => classNameToDropdownItem(e, true)).toList(),
                  onChanged: (val) {
                    setState(() => selectedTeacher = val!);
                    Provider.of<InternalState>(context, listen: false).lastSelectedTeacherPlan = val!;
                  },
                  value: selectedTeacher,
                ),
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: StuPlanDisplay(
                key: teacherPlanDisplayKey,
                selected: selectedTeacher,
                mode: SPDisplayMode.teacherPlan,
                showInfo: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    // the StuPlanData should have data here because the user already went through
    // the class and subject select screen, which loads it
    final available = Provider.of<StuPlanData>(context, listen: false).availableTeachers;
    final lastSelected = Provider.of<InternalState>(context, listen: false).lastSelectedTeacherPlan;
    selectedTeacher = (available!.contains(lastSelected) && lastSelected != null) ? lastSelected : available.first;
    super.initState();
  }
}

final teacherPlanDisplayKey = GlobalKey<StuPlanDisplayState>();

void teacherPlanRefreshAction() {
  teacherPlanDisplayKey.currentState?.forceRefreshData(); 
}
