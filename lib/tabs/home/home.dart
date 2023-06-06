import 'package:flutter/material.dart';
import 'package:kepler_app/info_screen.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/home/news_home.dart';
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
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: HomeNewsWidget()
            ),
            Consumer<AppState>(
              builder: (context, value, child) => ElevatedButton(
                onPressed: () => value.setInfoScreen(
                  InfoScreenDisplay(
                    infoScreens: [
                      const InfoScreen(closeable: false, infoText: Text("hi"), infoTitle: Text("Info. - nicht closeable"),),
                      const InfoScreen(closeable: true, infoText: Text("das ist eine Info."), infoTitle: Text("Digga, bitte geb uns mal dein Geld.\nWir brauchen das wirklich dringend."),),
                      const InfoScreen(closeable: true, infoText: Text("testt"), infoTitle: Text("closeable"), secondaryText: Text("mooore text"), infoImage: Icon(Icons.abc),),
                      InfoScreen(closeable: true, customScreen: Container(color: Colors.cyan.shade400),)
                    ],
                  ),
                ),
                child: const Text("info screen test"),
              )
            ),
            ElevatedButton(
              onPressed: () => prefs.darkTheme = !prefs.darkTheme,
              child: const Text("toggle dark theme"),
            ),
          ],
        ),
      ),
    );
  }
}
