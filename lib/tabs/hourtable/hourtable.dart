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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kepler_app/build_vars.dart';
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

/// Hauptseite für alle Unterseiten bzgl. des Stundenplans - ordnet die NavIds den tatsächlichen Seiten zu
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
        /// Das sollte eigentlich nie erreicht werden, da der Eintrag nicht ausgewählt werden kann, wenn Daten fehlen.
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
        if (navPage == StuPlanPageIDs.yours) return YourPlanPage();
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
        if (kDebugFeatures && navPage == StuPlanPageIDs.debug) return Text("Debug: ${utf8.decode(base64Url.decode(state.selectedNavPageIDs[1]))}");
        return const Text("Unbekannter Plan gefordert. Bitte schließen und erneut probieren.");
      },
    );
  }

  @override
  void initState() {
    super.initState();
  }
}

/// fehlen Daten für den Stundenplan -> sollte die Stundenplan-Einrichtung angezeigt werden?
bool shouldShowStuPlanIntro(StuPlanData data, bool teacher) =>
    teacher ? (data.selectedTeacherName == null) : (data.selectedClassName == null || data.selectedCourseIDs.isEmpty);

// returns true if all data is given and the stuplan page should be shown
// and false if the intro screens have to be shown -> for Drawer onTryOpen
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
