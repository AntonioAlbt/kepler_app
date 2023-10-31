import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';
import 'package:provider/provider.dart';

class ClassPlanPage extends StatefulWidget {
  const ClassPlanPage({super.key});

  @override
  State<ClassPlanPage> createState() => _ClassPlanPageState();
}

final classPlanDisplayKey = GlobalKey<StuPlanDisplayState>();

class _ClassPlanPageState extends State<ClassPlanPage> {
  late String selectedClass;

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
                  items: stdata.availableClasses.map((e) => classNameToDropdownItem(e, false)).toList(),
                  onChanged: (val) {
                    setState(() => selectedClass = val!);
                    Provider.of<InternalState>(context, listen: false).lastSelectedClassPlan = val!;
                  },
                  value: selectedClass,
                ),
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: StuPlanDisplay(
                key: classPlanDisplayKey,
                selected: selectedClass,
                mode: SPDisplayMode.classPlan,
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
    final available = Provider.of<StuPlanData>(context, listen: false).availableClasses;
    final lastSelected = Provider.of<InternalState>(context, listen: false).lastSelectedClassPlan;
    selectedClass = (available.contains(lastSelected) && lastSelected != null) ? lastSelected : available.first;
    super.initState();
  }
}

void classPlanRefreshAction() {
  classPlanDisplayKey.currentState?.forceRefreshData();
}
