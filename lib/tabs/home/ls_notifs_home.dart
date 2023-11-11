import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/widgets.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/lernsax/pages/notifs_page.dart';
import 'package:provider/provider.dart';

class HomeLSNotifsWidget extends StatelessWidget {
  const HomeLSNotifsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeWidgetBase(
      color: hasDarkTheme(context) ? colorWithLightness(const Color.fromARGB(255, 47, 135, 207), .1) : Colors.blue,
      title: const Text("LernSax: Benachrichtigungen"),
      child: Consumer<LernSaxData>(
        builder: (context, lsdata, _) {
          final notifs = lsdata.notifications;
          if (notifs == null || notifs.isEmpty) {
            return const Center(child: Text("Benachrichtigungen konnten nicht geladen werden."));
          }
          final notif = notifs.sublist(0, min(3, notifs.length));
          return Column(
            children: separatedListViewWithDividers(
              notif.map<Widget>((data) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: LSNotificationTile(notif: data),
              )).toList()
                ..add(
                  ListTile(
                    title: const Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text("Alle Benachrichtigungen"),
                        ),
                        Icon(Icons.open_in_new, size: 20),
                      ],
                    ),
                    onTap: () {
                      Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [
                        LernSaxPageIDs.main,
                        LernSaxPageIDs.notifications
                      ];
                    },
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  ),
                ),
            ),
          );
        },
      ),
    );
  }
}
