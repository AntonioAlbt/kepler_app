import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/libs/widgets.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/navigation.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/lernsax/pages/tasks_page.dart';
import 'package:provider/provider.dart';

class HomeLSTasksWidget extends StatefulWidget {
  final String id;

  const HomeLSTasksWidget({super.key, required this.id});

  @override
  State<HomeLSTasksWidget> createState() => _HomeLSTasksWidgetState();
}

class _HomeLSTasksWidgetState extends State<HomeLSTasksWidget> {
  bool loading = true;
  List<LSTask>? tasksSlice;

  @override
  Widget build(BuildContext context) {
    return HomeWidgetBase(
      id: widget.id,
      color: hasDarkTheme(context) ? colorWithLightness(const Color.fromARGB(255, 35, 126, 13), .1) : Colors.green.shade400,
      title: const Text("LernSax: Aufgaben"),
      child: Builder(
        builder: (context) {
          if (loading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Lädt..."),
              ),
            );
          }
          if (tasksSlice == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Fehler beim Laden."),
              ),
            );
          }
          if (tasksSlice!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Keine Aufgaben. Bitte die Seite \"Alle Aufgaben\" öffnen."),
              ),
            );
          }
          return Column(
            children: separatedListViewWithDividers(
              tasksSlice!.map<Widget>((data) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: LSTaskEntry(task: data, online: true),
              )).toList()
                ..add(
                  ListTile(
                    title: const Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text("Alle Aufgaben"),
                        ),
                        Icon(Icons.open_in_new, size: 20),
                      ],
                    ),
                    onTap: () {
                      Provider.of<AppState>(context, listen: false).selectedNavPageIDs = [
                        LernSaxPageIDs.main,
                        LernSaxPageIDs.tasks,
                      ];
                    },
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  ),
                ),
            ),
          );
        }
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Provider.of<CredentialStore>(context, listen: false).addListener(loadData);
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
    });

    final tasks = Provider.of<LernSaxData>(context, listen: false).tasks ?? [];
    tasksSlice = tasks.sublist(0, min(3, tasks.length));

    if (tasksSlice!.isEmpty) {
      // this only loads tasks from the user themselves, because i don't want to bother loading all tasks just for this widget
      // all widgets will be considered if the users opens the task page
      final creds = Provider.of<CredentialStore>(context, listen: false);
      final (online, tasks) = await lernsax.getTasks(creds.lernSaxLogin!, creds.lernSaxToken!);
      if (!online || tasks == null) {
        tasksSlice = null;
        return;
      }
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // Provider.of<LernSaxData>(context, listen: false).tasks = tasks;
      tasksSlice = tasks.sublist(0, min(3, tasks.length));
    }

    setState(() {
      loading = false;
    });
  }

  @override
  void dispose() {
    // i have to use the global context here because the widget context is already marked as deactivated
    Provider.of<CredentialStore>(globalScaffoldContext, listen: false).removeListener(loadData);
    super.dispose();
  }
}
