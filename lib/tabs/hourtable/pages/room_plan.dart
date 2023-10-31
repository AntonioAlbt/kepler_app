import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/hourtable/ht_intro.dart';
import 'package:kepler_app/tabs/hourtable/pages/free_rooms.dart';
import 'package:kepler_app/tabs/hourtable/pages/plan_display.dart';
import 'package:provider/provider.dart';

final roomPlanDisplayKey = GlobalKey<StuPlanDisplayState>();

class RoomPlanPage extends StatefulWidget {
  const RoomPlanPage({super.key});

  @override
  State<RoomPlanPage> createState() => RoomPlanPageState();
}

class RoomPlanPageState extends State<RoomPlanPage> {
  late String selectedRoom;

  @override
  Widget build(BuildContext context) {
    return Consumer<CredentialStore>(
      builder: (context, creds, _) => Column(
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
                  items: allKeplerRooms.map((e) => classNameToDropdownItem(e, true)).toList(),
                  onChanged: (val) {
                    setState(() => selectedRoom = val!);
                    Provider.of<InternalState>(context, listen: false).lastSelectedRoomPlan = val!;
                  },
                  value: selectedRoom,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 8, right: 8),
            child: Text(
              "Achtung: Raumpläne sind nicht immer zutreffend, und nicht für alle Räume sind Daten vorhanden.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.5),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: StuPlanDisplay(
                key: roomPlanDisplayKey,
                selected: selectedRoom,
                mode: SPDisplayMode.roomPlan,
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
    final lastSelected = Provider.of<InternalState>(context, listen: false).lastSelectedRoomPlan;
    selectedRoom = (allKeplerRooms.contains(lastSelected) && lastSelected != null) ? lastSelected : allKeplerRooms.first;
    super.initState();
  }
}

void roomPlanRefreshAction() {
  roomPlanDisplayKey.currentState?.forceRefreshData();
}
