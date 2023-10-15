import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/lernsax/pages/notifs_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:url_launcher/url_launcher.dart';

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
  bool _loadingClasses = false;
  String? selectedClass;
  
  @override
  Widget build(BuildContext context) {
    if (_loadingClasses) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Consumer<LernSaxData>(
      builder: (context, lsdata, child) {
        if (lsdata.memberships == null) {
          return Center(
            child: Column(
              children: [
                const Text(
                  "Fehler beim Abfragen. Ist Internet vorhanden?",
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ElevatedButton(
                    onPressed: loadData,
                    child: const Text("Erneut versuchen"),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            SizedBox(
              height: 50,
              child: AppBar(
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                elevation: 5,
                bottom: PreferredSize(
                  preferredSize: const Size(100, 50),
                  child: DropdownButton<String>(
                    items: lsdata.memberships?.where((e) => e.effectiveRights.contains("tasks"))
                      .map((e) => DropdownMenuItem<String>(value: e.login, child: Text(e.name))).toList()
                      ?..insert(0, const DropdownMenuItem<String>(value: null, child: Text("Eigene Aufgaben")))
                      ..insert(0, const DropdownMenuItem<String>(value: "all", child: Text("Alle Aufgaben"))),
                    onChanged: (val) {
                      setState(() => selectedClass = val);
                      Provider.of<InternalState>(context, listen: false).lastSelectedLSTaskClass = val;
                    },
                    value: selectedClass,
                  ),
                ),
              ),
            ),
            Flexible(
              child: LSTaskDisplay(selectedClass: selectedClass, key: ValueKey(selectedClass)),
            ),
          ],
        );
      }
    );
  }

  @override
  void initState() {
    selectedClass = Provider.of<InternalState>(context, listen: false).lastSelectedLSTaskClass;
    loadData();
    super.initState();
  }

  Future<void> loadData() async {
    setState(() => _loadingClasses = true);
    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final classes = await lernsax.getGroupsAndClasses(creds.lernSaxLogin, creds.lernSaxToken!);
    if (classes == null) {
      showSnackBar(textGen: (sie) => "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} Klassen/Gruppen. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
      setState(() => _loadingClasses = false);
    } else {
      lsdata.memberships = classes;
      setState(() => _loadingClasses = false);
    }
  }
}

class LSTaskDisplay extends StatefulWidget {
  final String? selectedClass;

  const LSTaskDisplay({super.key, required this.selectedClass});

  @override
  State<LSTaskDisplay> createState() => _LSTaskDisplayState();
}

const linkRegex = r"(([A-Za-z]{3,9}:(?:\/\/)?)(?:[\-;:&=\+\$,\w]+@)?[A-Za-z0-9\.\-]+|(?:www\.|[\-;:&=\+\$,\w]+@)[A-Za-z0-9\.\-]+)((?:\/[\+~%\/\.\w\-_]*)?\??(?:[\-\+=&;%@\.\w_]*)#?(?:[\.\!\/\\\w]*))?";

class _LSTaskDisplayState extends State<LSTaskDisplay> {
  bool _loading = true;
  // TODO: use this when making tasks able to be completed (disable if not connected)
  // ignore: unused_field
  bool _connected = false;
  int _loadingProgress = -1;
  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (_loadingProgress > -1) Padding(
              padding: const EdgeInsets.all(8),
              child: Text("Lädt... $_loadingProgress %"),
            ),
          ],
        ),
      );
    }
    return Consumer2<LernSaxData, InternalState>(
      builder: (context, lsdata, istate, _) {
        final tasks = lsdata.tasks?.where((e) => e.classLogin == widget.selectedClass || widget.selectedClass == "all")
          .where((e) => (!istate.lastSelectedLSTaskShowDone) ? !e.completed : true).toList();
        if (tasks == null) {
          return const Center(
            child: Text(
              "Aufgaben konnten nicht abgefragt werden.",
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          );
        }
        return Column(
          children: [
            CheckboxListTile(
              value: istate.lastSelectedLSTaskShowDone,
              onChanged: (val) {
                istate.lastSelectedLSTaskShowDone = !istate.lastSelectedLSTaskShowDone;
              },
              title: const Text("Abgeschlossene anzeigen"),
            ),
            if (tasks.isEmpty) const Expanded(
              child: Center(
                child: Text(
                  "Keine Aufgaben vorhanden.",
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            if (tasks.isNotEmpty) Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: tasks.length,
                itemBuilder: (context, i) {
                  final task = tasks[i];
                  return Padding(
                    padding: (i > 0)
                        ? const EdgeInsets.symmetric(horizontal: 4)
                        : const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        textStyle: Theme.of(context).textTheme.bodyMedium,
                        foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      // onPressed: () => showDialog(context: context, builder: (ctx) => generateLernSaxNotifInfoDialog(ctx, notif)), // TODO: create generateLernSaxTaskInfoDialog
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
                              Flexible(
                                  child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(task.title),
                              )),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.list),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Html(
                                    data: task.description
                                      .replaceAll("\r", "")
                                      .replaceAll("\n\n\n", "\n\n")
                                      .replaceAll("\n", "<br>")
                                      .replaceAllMapped(RegExp(linkRegex, multiLine: true), (match) => "<a href=\"${match.group(0)}\">${match.group(0)}</a>"),
                                    onLinkTap: (url, _, __) {
                                      try {
                                        launchUrl(Uri.parse((!url!.startsWith("http")) ? "http://$url" : url), mode: LaunchMode.externalApplication);
                                      } catch (_) {}
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(MdiIcons.clock),
                              Flexible(
                                  child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text("Start: ${task.startDate != null ? lernSaxTimeFormat.format(task.startDate!) : "-"}"),
                              )),
                              const SizedBox(width: 10),
                              const Icon(MdiIcons.clock),
                              Flexible(
                                  child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text("Ende: ${task.dueDate != null ? lernSaxTimeFormat.format(task.dueDate!) : "-"}"),
                              )),
                            ],
                          ),
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
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    loadTasksForSelectedClass();
    super.initState();
  }

  Future<void> loadTasksForSelectedClass() async {
    setState(() => _loading = true);
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    var connected = false;
    if (widget.selectedClass == "all") {
      setState(() => _loadingProgress = 0);
      final data = <LSTask>[];
      final failed = <String>[];
      
      final memberships = lsdata.memberships!.where((m) => m.effectiveRights.contains("tasks"));
      for (final (i, membership) in memberships.indexed) {
        final newData = await lernsax.getTasks(creds.lernSaxLogin, creds.lernSaxToken!, classLogin: membership.login);
        if (newData == null) {
          failed.add(membership.name);
        } else {
          data.addAll(newData);
        }
        setState(() => _loadingProgress = ((i + 1) / memberships.length * 100).round());
      }

      if (failed.isNotEmpty) {
        showSnackBar(textGen: (sie) => "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} Aufgaben aus den Klassen/Gruppen: ${failed.join(", ")}. Bitte ${sie ? "probieren Sie" : "probiere"} es später erneut.", error: true, clear: true);
      }
      if (data.isEmpty) {
        showSnackBar(textGen: (sie) =>  "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} Aufgaben, oder ${sie ? "Sie haben" : "Du hast"} keine Aufgaben. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
      } else {
        connected = true;
        lsdata.addNewTasks(data);
      }
    } else {
      final data = await lernsax.getTasks(creds.lernSaxLogin, creds.lernSaxToken!, classLogin: widget.selectedClass);
      if (data == null) {
        showSnackBar(textGen: (sie) =>  "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} Aufgaben. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
      } else {
        lsdata.addNewTasks(data);
        connected = true;
      }
    }
    setState(() {
      _loading = false;
      _connected = connected;
    });
  }
}
