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
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/main.dart';
import 'package:kepler_app/rainbow.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:kepler_app/tabs/lernsax/pages/mail_detail_page.dart';
import 'package:kepler_app/tabs/lernsax/pages/notifs_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:url_launcher/url_launcher.dart';

final lsTaskPageKey = GlobalKey<_LSTasksPageState>();

void lernSaxTasksRefreshAction() {
  lsTaskPageKey.currentState?.loadData(force: true);
}

class LSTasksPage extends StatefulWidget {
  final String login;
  final String token;
  final bool alternative;

  LSTasksPage(this.login, this.token, this.alternative) : super(key: lsTaskPageKey);

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
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
            ),
          );
        }
        return Column(
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

  Future<void> loadData({ bool force = false }) async {
    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    // only update membership data every 3 days because it doesn't change as often
    if (lsdata.lastMembershipsUpdateDiff.inDays < 3 && !force) return;

    setState(() => _loadingClasses = true);
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final (online, classes) = await lernsax.getGroupsAndClasses(creds.lernSaxLogin!, creds.lernSaxToken!);
    if (!online) {
      showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
    } else if (classes == null) {
      showSnackBar(textGen: (sie) => "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} Klassen/Gruppen. Bitte ${sie ? "probieren Sie" : "probiere"} es später erneut.", error: true, clear: true);
    } else {
      lsdata.memberships = classes;
      lsdata.lastMembershipsUpdate = DateTime.now();
      showSnackBar(text: "Aufgaben erfolgreich aktualisiert.", duration: const Duration(seconds: 1));
    }
    setState(() => _loadingClasses = false);
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
            if (!_connected) const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.grey),
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text("Offline-Modus: Aufgaben können nicht verändert werden. Aktualisieren, um zu deaktivieren."),
                    ),
                  ),
                ],
              ),
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
              child: RefreshIndicator(
                onRefresh: loadTasksForSelectedClass,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tasks.length,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    return Padding(
                      padding: (i > 0)
                          ? const EdgeInsets.symmetric(horizontal: 4)
                          : const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
                      child: LSTaskEntry(task: task, online: _connected),
                    );
                  },
                  separatorBuilder: (context, i) => const Divider(),
                ),
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
    // widget.controller?.onForceRefresh = () => loadTasksForSelectedClass();
  }

  Future<bool?> loadTasksForSelectedClass() async {
    setState(() => _loading = true);
    final creds = Provider.of<CredentialStore>(context, listen: false);
    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    var connected = false;
    var text = "";
    if (widget.selectedClass == "all") {
      setState(() => _loadingProgress = 0);
      final data = <LSTask>[];
      final failed = <String>[];
      
      // null is representing the users own tasks
      final memberships = lsdata.memberships!.where((m) => m.effectiveRights.contains("tasks")).cast<LSMembership?>().toList()..add(null);
      for (final (i, membership) in memberships.indexed) {
        final (online, newData) = await lernsax.getTasks(creds.lernSaxLogin!, creds.lernSaxToken!, classLogin: membership?.login);

        if (!mounted) return null;
        if (!online) {
          text = (online == false && lsdata.lastTasksUpdateDiff.inHours >= 24 && lsdata.tasks != null) ? " Hinweis: Die Daten sind älter als 24 Stunden. Es könnten neue Aufgaben verfügbar sein." : "";
          showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?$text", clear: true, error: true);
          setState(() => _loading = false);
          return false;
        }
        
        if (newData == null) {
          failed.add(membership?.name ?? "Eigene");
        } else {
          data.addAll(newData);
        }
        setState(() => _loadingProgress = ((i + 1) / memberships.length * 100).round());
      }

      if (failed.isNotEmpty) {
        showSnackBar(textGen: (sie) => "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} Aufgaben aus den Klassen/Gruppen: ${failed.join(", ")}. Bitte ${sie ? "probieren Sie" : "probiere"} es später erneut.", error: true, clear: true);
      }
      if (failed.length == memberships.length) {
        showSnackBar(textGen: (sie) => "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} aktuellen Aufgaben, oder ${sie ? "Sie haben" : "Du hast"} keine Aufgaben. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
      } else {
        connected = true;
        lsdata.addTasksNew(data);
      }
    } else {
      final (online, data) = await lernsax.getTasks(creds.lernSaxLogin!, creds.lernSaxToken!, classLogin: widget.selectedClass);
      final text = (online == false && lsdata.lastTasksUpdateDiff.inHours >= 24 && lsdata.tasks != null) ? " Hinweis: Die Daten sind älter als 24 Stunden. Es könnten neue Aufgaben verfügbar sein." : "";
      if (!online) {
        showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?$text", error: true, clear: true);
      } else if (data == null) {
        showSnackBar(textGen: (sie) => "Fehler beim Abfragen ${sie ? "Ihrer" : "Deiner"} aktuellen Aufgaben. Bitte ${sie ? "probieren Sie" : "probiere"} es später erneut.$text", error: true, clear: true);
      } else {
        lsdata.addTasksNew(data);
        connected = true;
      }
    }
    if (!mounted) return null;
    setState(() {
      _loading = false;
      _connected = connected;
    });
    return true;
  }
}

class LSTaskEntry extends StatefulWidget {
  const LSTaskEntry({
    super.key,
    required this.task,
    required this.online,
    this.darkerIcons = false,
  });

  final LSTask task;
  final bool online;
  final bool darkerIcons;

  @override
  State<LSTaskEntry> createState() => _LSTaskEntryState();
}

class _LSTaskEntryState extends State<LSTaskEntry> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool taskCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Padding(
        //   padding: const EdgeInsets.only(bottom: 4),
        //   child: Row(
        //     children: [
        //       Icon(MdiIcons.clock, size: 16, color: Colors.grey),
        //       Padding(
        //         padding: const EdgeInsets.only(left: 4),
        //         child: Text(lernSaxTimeFormat.format(widget.task.createdAt)),
        //       ),
        //     ],
        //   ),
        // ),
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: LSTaskCheckBox(
                checked: widget.task.completed,
                updateChecked: (val) async {
                  if (widget.task.classLogin != null) {
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Hinweis"),
                        content: Text("Leider können Aufgaben aus Klassen aufgrund eines LernSax-Fehlers aktuell nicht abgehakt werden. ${Provider.of<Preferences>(context, listen: false).preferredPronoun == Pronoun.sie ? "Sie können" : "Du kannst"} die Aufgabe stattdessen auf der Webseite per Link abhaken."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Abbrechen")),
                          TextButton(onPressed: () {
                            Navigator.pop(ctx);
                            showSnackBar(text: "Erstellt Link...", clear: true, duration: const Duration(seconds: 10));
                            final creds = Provider.of<CredentialStore>(context, listen: false);
                            lernsax.getSingleUseLoginLink(creds.lernSaxLogin!, creds.lernSaxToken!, targetLogin: widget.task.classLogin, targetObject: "tasks")
                              .then((data) {
                                final (online, url) = data;
                                if (!online) {
                                  showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
                                } else if (url == null) {
                                  showSnackBar(text: "Fehler bei der Erstellung des Links.", error: true, clear: true);
                                } else {
                                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                                    .then((_) => showSnackBar(text: "Link wird geöffnet.", clear: true, duration: const Duration(milliseconds: 100)))
                                    .onError((_, __) => showSnackBar(text: "Fehler beim Öffnen des Links.", error: true, clear: true));
                                }
                              });
                          }, child: const Text("Im Browser öffnen")),
                        ],
                      ),
                    );
                    return false;
                  } else {
                    final creds = Provider.of<CredentialStore>(context, listen: false);
                    final (online, data) = await lernsax.modifyTask(
                      creds.lernSaxLogin!,
                      creds.lernSaxToken!,
                      id: widget.task.id,
                      classLogin: null,
                      completed: val,
                    );
                    if (!online) {
                      showSnackBar(textGen: (sie) => "Fehler bei der Verbindung zu LernSax. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
                    } else if (data == null) {
                      showSnackBar(text: "Fehler bei der Aktualisierung der Aufgabe.", error: true, clear: true);
                    } else {
                      Provider.of<LernSaxData>(context, listen: false).addTasksNew([data]);
                      setState(() => taskCompleted = !taskCompleted);
                      return true;
                    }
                    return false;
                  }
                },
                enabled: widget.online,
                darkerColors: widget.darkerIcons,
              ),
            ),
            Flexible(
              child: LSTaskTile(task: widget.task, completed: taskCompleted, darkerIcons: widget.darkerIcons),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    taskCompleted = widget.task.completed;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class LSTaskTile extends StatelessWidget {
  final LSTask task;
  final bool completed;
  final bool darkerIcons;

  const LSTaskTile({
    super.key,
    required this.task,
    required this.completed,
    required this.darkerIcons,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        textStyle: Theme.of(context).textTheme.bodyMedium,
        foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () {
        if (task.description != "") {
          showDialog(context: context, builder: (context) => generateLernSaxTaskInfoDialog(context, task));
        } else {
          showSnackBar(text: "Keine weiteren Infos verfügbar.", clear: true, duration: const Duration(milliseconds: 500));
        }
      },
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: SizedBox(
              key: ValueKey("${task.title}$completed"),
              width: double.infinity,
              child: Text(
                task.title,
                style: (completed) ? const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 16, decorationThickness: 2) : const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          if (task.description != "") const SizedBox(
            width: double.infinity,
            child: Text(
              "Tippen, um Infos zur Aufgabe anzusehen.",
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
            ),
          ),
          if (kDebugFeatures) SizedBox(
            width: double.infinity,
            child: Text(
              "Class Login: ${task.classLogin}",
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    key: ValueKey(_shouldBeCompleted()),
                    MdiIcons.clock,
                    size: 18,
                    color: _shouldBeCompleted() ? Colors.red : null,
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(_getDateInfoString(), style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(MdiIcons.account, size: 18, color: darkerIcons ? Colors.grey.shade900 : Colors.grey),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: "von "),
                        createLSNameMailSpan(task.createdByName, task.createdByLogin, addComma: false, translate: const Offset(0, 2), darkerIcon: darkerIcons),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDateInfoString() {
    final startDefined = task.startDate != null;// && task.startDate!.millisecondsSinceEpoch > 100;
    if (startDefined || task.dueDate != null) {
      return ((startDefined) ? "vom ${lernSaxTimeFormat.format(task.startDate!)}" : "") + (startDefined && task.dueDate != null ? "\n" : "") + ((task.dueDate != null) ? "bis zum ${lernSaxTimeFormat.format(task.dueDate!)}" : "");
    } else {
      return "erstellt am ${lernSaxTimeFormat.format(task.createdAt)}";
    }
  }

  bool _shouldBeCompleted() {
    final due = task.dueDate;
    if (due == null || completed) return false;
    return due.isBefore(DateTime.now());
  }
}

class LSTaskCheckBox extends StatefulWidget {
  final bool checked;
  final bool enabled;
  final Future<bool> Function(bool val)? updateChecked;
  final bool darkerColors;
  const LSTaskCheckBox({super.key, this.checked = false, this.updateChecked, this.enabled = true, this.darkerColors = false});

  @override
  State<LSTaskCheckBox> createState() => _LSTaskCheckBoxState();
}

class _LSTaskCheckBoxState extends State<LSTaskCheckBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late bool checked;
  bool _loading = false;

  void _processCheck() {
    if (checked) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() => checked = !checked);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {
          if (!widget.enabled || _loading) return;

          if (widget.updateChecked != null) {
            setState(() => _loading = true);
            widget.updateChecked!(!checked).then((val) {
              if (!mounted) return;
              if (val) _processCheck();
              setState(() => _loading = false);
            });
          } else {
            _processCheck();
          }
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: RainbowWrapper(
                builder: (context, color) {
                  if (color == null) {
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getColor(),
                            width: 2,
                          ),
                          color: (!widget.enabled) ? (hasDarkTheme(context) ? Colors.grey.shade800 : Colors.grey.shade200) : null,
                        ),
                        width: 20,
                        height: 20,
                      ),
                    );
                  } else {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color,
                          width: 2,
                        ),
                        color: (!widget.enabled) ? (hasDarkTheme(context) ? Colors.grey.shade800 : Colors.grey.shade200) : null,
                      ),
                      width: 20,
                      height: 20,
                    );
                  }
                }
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 6),
              child: Center(
                child: ScaleTransition(
                  scale: _controller,
                  child: RainbowWrapper(
                    builder: (context, color) {
                      if (color == null) {
                        return AnimatedBuilder(
                          animation: _controller,
                          builder: (_, __) => Icon(
                            Icons.check,
                            size: 16,
                            grade: 200,
                            weight: 700,
                            opticalSize: 20,
                            color: _getColor(),
                          ),
                        );
                      } else {
                        return Icon(
                          Icons.check,
                          size: 16,
                          grade: 200,
                          weight: 700,
                          opticalSize: 20,
                          color: color,
                        );
                      }
                    }
                  ),
                ),
              ),
            ),
            if (_loading) const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 8, left: 8),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    checked = widget.checked;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 50),
    );
    if (widget.checked) _controller.animateTo(1, duration: const Duration());
  }

  Color _getColor() {
    if (!widget.enabled) return Colors.grey;
    return ColorTween(
      begin: hasDarkTheme(context) ? Colors.white : Colors.black,
      end: hasDarkTheme(context) ? Colors.green.shade400 : (widget.darkerColors ? Colors.green.shade900 : Colors.green.shade600),
    ).lerp(_controller.value)!;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

Widget generateLernSaxTaskInfoDialog(BuildContext context, LSTask task) {
  final originMshp = Provider.of<LernSaxData>(globalScaffoldContext, listen: false).memberships?.cast<LSMembership?>().firstWhere((m) => m!.login == task.classLogin, orElse: () => null);
  return AlertDialog(
    title: const Text("Aufgabe"),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(task.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          Text(originMshp?.name ?? "Eigene Aufgabe"),
          const Text(""),
          SelectableLinkify(
            text: task.description.replaceAll(RegExp(r"</?[a-z=]{1,20}>"), ""),
            linkifiers: const [UrlLinkifier()],
            onOpen: (url){
              try {
                launchUrl(Uri.parse(url.url), mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
          ),
          const Text(""),
          Text("- erstellt am ${lernSaxTimeFormat.format(task.createdAt)} von ${task.createdByName} (${task.createdByLogin})"),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Schließen")),
    ],
  );
}
