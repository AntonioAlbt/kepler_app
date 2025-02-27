// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2023-2024 Antonio Albert

// This file is part of kepler_app.

// kepler_app is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// kepler_app is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with kepler_app.  If not, see <http://www.gnu.org/licenses/>.

// Diese Datei ist Teil von kepler_app.

// kepler_app ist Freie Software: Sie können es unter den Bedingungen
// der GNU General Public License, wie von der Free Software Foundation,
// Version 3 der Lizenz oder (nach Ihrer Wahl) jeder neueren
// veröffentlichten Version, weiter verteilen und/oder modifizieren.

// kepler_app wird in der Hoffnung, dass es nützlich sein wird, aber
// OHNE JEDE GEWÄHRLEISTUNG, bereitgestellt; sogar ohne die implizite
// Gewährleistung der MARKTFÄHIGKEIT oder EIGNUNG FÜR EINEN BESTIMMTEN ZWECK.
// Siehe die GNU General Public License für weitere Details.

// Sie sollten eine Kopie der GNU General Public License zusammen mit
// kepler_app erhalten haben. Wenn nicht, siehe <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:kepler_app/libs/logging.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/rainbow.dart';
import 'package:kepler_app/tabs/hourtable/ht_data.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';
import 'package:provider/provider.dart';

/// wie Klassenplan, aber nur für Lehrer
class TeacherPlanPage extends StatefulWidget {
  const TeacherPlanPage({super.key});

  @override
  State<TeacherPlanPage> createState() => _TeacherPlanPageState();
}

class _TeacherPlanPageState extends State<TeacherPlanPage> {
  String? _error;
  late String selectedTeacher;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text("Fehler beim Anzeigen: $_error"),
      ));
    }
    return Consumer<StuPlanData>(
      builder: (context, stdata, _) => Stack(
        children: [
          RainbowWrapper(builder: (_, color) => Container(color: color?.withValues(alpha: .5))),
          Column(
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
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // the StuPlanData should have data here because the user already went through
    // the class and subject select screen, which loads it
    final available = Provider.of<StuPlanData>(context, listen: false).availableTeachers;
    final lastSelected = Provider.of<InternalState>(context, listen: false).lastSelectedTeacherPlan;
    if (available == null) {
      _error = "Laden der verfügbaren Klassen fehlgeschlagen. Bitte App neustarten.";
      logError("teacherplan", "availableTeachers was null, for ${Provider.of<AppState>(context, listen: false).userType}, last selected: $lastSelected");
      return;
    }
    selectedTeacher = (available.contains(lastSelected) && lastSelected != null) ? lastSelected : available.first;
  }
}

final teacherPlanDisplayKey = GlobalKey<StuPlanDisplayState>();

void teacherPlanRefreshAction() {
  teacherPlanDisplayKey.currentState?.forceRefreshData(); 
}
