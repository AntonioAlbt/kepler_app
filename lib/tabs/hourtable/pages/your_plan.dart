import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:kepler_app/libs/indiware.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
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
              selected: stdata.selectedClassName!,
              mode: SPDisplayMode.yourPlan,
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

Widget generateLessonInfoDialog(BuildContext context, VPLesson lesson, VPCSubjectS? subject, String? classNameToReplace) {
  return AlertDialog(
    title: Text("Infos zur ${lesson.schoolHour}. Stunde"),
    content: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lesson.startTime != null && lesson.endTime != null) Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  const WidgetSpan(child: Icon(Icons.access_time, color: Colors.grey)),
                  const TextSpan(text: " "),
                  TextSpan(text: "${lesson.startTime} bis ${lesson.endTime}"),
                ],
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(Icons.school, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: lesson.subjectCode.replaceFirst(classNameToReplace ?? "funny joke.", "")),
                    if (lesson.subjectChanged) const TextSpan(text: ", "),
                    if (lesson.subjectChanged)
                      const TextSpan(
                        text: "geändert",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    if (lesson.subjectChanged && subject != null && subject.subjectCode != lesson.subjectCode) TextSpan(
                      text: " (sonst ${subject.subjectCode}${(subject.additionalDescr != null) ? " (${subject.additionalDescr})" : ""})"
                    ),
                  ],
                ),
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(MdiIcons.humanMaleBoard, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: (lesson.teacherCode == "") ? "---" : lesson.teacherCode),
                    if (lesson.teacherChanged) const TextSpan(text: ", "),
                    if (lesson.teacherChanged)
                      const TextSpan(
                        text: "geändert",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    if (lesson.teacherChanged && subject != null && subject.teacherCode != lesson.teacherCode) TextSpan(
                      text: " (sonst ${subject.teacherCode})"
                    ),
                  ],
                ),
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(MdiIcons.door, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: (lesson.roomCodes.isEmpty) ? "---" : lesson.roomCodes.join(", ")),
                    if (lesson.roomChanged) const TextSpan(text: ", "),
                    if (lesson.roomChanged)
                      const TextSpan(
                        text: "geändert",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (lesson.infoText != "") Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(child: Icon(MdiIcons.informationOutline, color: Colors.grey)),
                    const TextSpan(text: " "),
                    TextSpan(text: lesson.infoText),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("Schließen"),
      ),
    ],
  );
}
