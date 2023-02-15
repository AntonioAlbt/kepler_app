import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/tabs/about.dart';
import 'package:kepler_app/tabs/ffjkg.dart';
import 'package:kepler_app/tabs/home.dart';
import 'package:kepler_app/tabs/hourtable.dart';
import 'package:kepler_app/tabs/lernsax.dart';
import 'package:kepler_app/tabs/meals.dart';
import 'package:kepler_app/tabs/settings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "",
      home: const KeplerApp(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: keplerColorBlue
        )
      ),
    );
  }
}

T? cast<T>(x) => x is T ? x : null;

final lernSaxIcon = Image.asset("assets/lernsax_icon.png", height: 24, width: 24, color: const Color.fromARGB(255, 0, 0, 0));
final lernSaxIconColorful = Image.asset("assets/lernsax_icon.png", height: 24, width: 24);

final destinations = <Widget>[
  const NavigationDrawerDestination(
    icon: Icon(Icons.home_outlined),
    label: Text("Startseite"),
    selectedIcon: Icon(Icons.home),
  ),
  const NavigationDrawerDestination(
    icon: Icon(Icons.school_outlined),
    label: Text("Stundenplan"),
    selectedIcon: Icon(Icons.school),
  ),
  NavigationDrawerDestination(
    icon: lernSaxIcon,
    label: const Text("LernSax"),
    selectedIcon: lernSaxIconColorful,
  ),
  const NavigationDrawerDestination(
    icon: Icon(Icons.restaurant_outlined),
    label: Text("Essensbestellung"),
    selectedIcon: Icon(Icons.restaurant),
  ),
  const Divider(),
  const NavigationDrawerDestination(
    icon: Icon(Icons.euro_outlined),
    label: Text("FFJKG"),
    selectedIcon: Icon(Icons.euro),
  ),
  const NavigationDrawerDestination(
    icon: Icon(Icons.settings_outlined),
    label: Text("Einstellungen"),
    selectedIcon: Icon(Icons.settings),
  ),
  const NavigationDrawerDestination(
    icon: Icon(Icons.info_outlined),
    label: Text("Über diese App"),
    selectedIcon: Icon(Icons.info),
  )
];

const tabs = [
  HomepageTab(),
  HourtableTab(),
  LernSaxTab(),
  MealOrderingTab(),
  FFJKGTab(),
  SettingsTab(),
  AboutTab()
];

class KeplerApp extends StatefulWidget {
  const KeplerApp({super.key});

  @override
  State<KeplerApp> createState() => _KeplerAppState();
}

class _KeplerAppState extends State<KeplerApp> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((_index == 0) ? "Kepler-App" : cast<Text>(cast<NavigationDrawerDestination>(destinations[(_index > 3) ? _index + 1 : _index])?.label)?.data ?? "Kepler-App"),
        scrolledUnderElevation: 5,
        elevation: 5,
      ),
      drawer: NavigationDrawer(
        selectedIndex: _index,
        onDestinationSelected: (val) {
          setState(() => _index = val);
          Navigator.pop(context);
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
            child: Column(
              children: [
                const Icon(Icons.filter_outlined, size: 104),
                Text("Kepler-App", style: Theme.of(context).textTheme.titleLarge)
              ],
            ),
          ),
          ...destinations
        ],
      ),
      body: tabs[_index],
      // drawer: Drawer(
      //   child: ListView(
      //     padding: EdgeInsets.zero,
      //     children: [
      //       const DrawerHeader(
      //         decoration: BoxDecoration(
      //           color: Colors.blue,
      //         ),
      //         child: Text('Kepler-App'),
      //       ),
      //       ListTile(
      //         leading: const Icon(Icons.home),
      //         title: const Text("Startseite"),
      //         onTap: () {
      //           _index = 0;
      //           Navigator.pop(context);
      //         },
      //       )
      //     ],
      //   ),
      // ),
    );
  }
}
