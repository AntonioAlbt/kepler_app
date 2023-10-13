import 'package:flutter/material.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/lernsax/pages/notifs_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;

final lsTaskPageKey = GlobalKey<_LSTasksPageState>();

void lernSaxTasksRefreshAction() {
  lsTaskPageKey.currentState?.loadData();
}

class LSTasksPage extends StatefulWidget {
  LSTasksPage() : super(key: lsTaskPageKey);

  @override
  State<LSTasksPage> createState() => _LSTasksPageState();
}

class _LSTasksPageState extends State<LSTasksPage> {
  bool _loading = false;
  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Consumer<LernSaxData>(
      builder: (context, lsdata, child) {
        if (lsdata.tasks?.isEmpty ?? true) {
          return const Center(
            child: Text(
              "Keine Aufgaben vorhanden.",
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          itemCount: lsdata.tasks.length,
          itemBuilder: (context, i) {
            final task = lsdata.tasks[i];
            return Padding(
              padding: (i > 0) ? const EdgeInsets.symmetric(horizontal: 4) : const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
              child: TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                  foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                // TODO: onPressed: () => showDialog(context: context, builder: (ctx) => generateLernSaxNotifInfoDialog(ctx, notif)),
                onPressed: () {},
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(MdiIcons.clock, size: 16, color: Colors.grey),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(lernSaxTimeFormat.format(task.createdAt)),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline),
                        Flexible(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(task.title),
                        )),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.list),
                        Flexible(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(task.description),
                        )),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(MdiIcons.clock),
                        Flexible(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text("Start: ${task.startDate != null ? lernSaxTimeFormat.format(task.startDate!) : "-"}"),
                        )),
                        const SizedBox(width: 10),
                        const Icon(MdiIcons.clock),
                        Flexible(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text("Ende: ${task.dueDate != null ? lernSaxTimeFormat.format(task.dueDate!) : "-"}"),
                        )),
                      ],
                    ),
                    // dont care about group login because no user can recognize that ever
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Row(
                        children: [
                          const Icon(MdiIcons.account),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text("${task.createdByName} (${task.createdByLogin})"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (context, i) => const Divider(),
        );
      }
    );
  }

  @override
  void initState() {
    loadData();
    super.initState();
  }

  Future<void> loadData() async {
    setState(() => _loading = true);
    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final data = await lernsax.getTasks(creds.lernSaxLogin, creds.lernSaxToken!);
    if (data == null) {
      ScaffoldMessenger.of(globalScaffoldKey.currentContext!)
        ..clearMaterialBanners()
        ..showSnackBar(SnackBar(content: Selector<Preferences, bool>(
          selector: (_, prefs) => prefs.preferredPronoun == Pronoun.sie,
          builder: (context, sie, _) {
            return Text("Fehler beim Abfragen neuer Benachrichtungen. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?");
          }
        )));
    } else {
      lsdata.tasks = data;
      // print(lsdata.tasks);
    }
    setState(() => _loading = false);
  }
}
