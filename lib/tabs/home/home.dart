import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/home/news_home.dart';
import 'package:kepler_app/tabs/home/stuplan_home.dart';
import 'package:provider/provider.dart';

class HomepageTab extends StatefulWidget {
  const HomepageTab({super.key});

  @override
  State<HomepageTab> createState() => _HomepageTabState();
}

class _HomepageTabState extends State<HomepageTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: HomeNewsWidget(),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: HomeStuPlanWidget(),
              ),
              if (kDebugMode) Consumer<AppState>(
                builder: (context, value, child) => ElevatedButton(
                  onPressed: () {
                    value.infoScreen = InfoScreenDisplay(
                      infoScreens: [
                        const InfoScreen(infoText: Text("hi"), infoTitle: Text("Info. - not closeable"), closeable: false,),
                        InfoScreen(closeable: true, infoText: const Text("das ist eine Info."), infoTitle: const Text("Digga, bitte geb uns mal dein Geld.\nWir brauchen das wirklich dringend."), onTryClose: (index, _) {
                          return Random().nextBool();
                        },),
                        const InfoScreen(closeable: true, infoText: Text("testt"), infoTitle: Text("closeable"), secondaryText: Text("mooore text"), infoImage: Icon(Icons.abc),),
                        InfoScreen(closeable: true, customScreen: Container(color: Colors.cyan.shade400),)
                      ],
                      scrollable: true,
                    );
                  },
                  child: const Text("info screen test"),
                )
              ),
              if (kDebugMode) Consumer<Preferences>(
                builder: (context, prefs, _) {
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => prefs.theme = (prefs.darkTheme) ? AppTheme.light : AppTheme.dark,
                        child: const Text("toggle dark theme"),
                      ),
                      ElevatedButton(
                        onPressed: () => prefs.theme = AppTheme.system,
                        child: const Text("reset theme to system"),
                      ),
                    ],
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }
}
