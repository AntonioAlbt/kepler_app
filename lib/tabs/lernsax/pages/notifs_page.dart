import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/lernsax/ls_data.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

final lernSaxTimeFormat = DateFormat("dd.MM.yyyy HH:MM:ss");

final lsNotifPageKey = GlobalKey<LSNotificationPageState>();

void lernSaxNotifsRefreshAction() {
  lsNotifPageKey.currentState?.loadData();
}

class LSNotificationPage extends StatefulWidget {
  LSNotificationPage() : super(key: lsNotifPageKey);

  @override
  State<LSNotificationPage> createState() => LSNotificationPageState();
}

class LSNotificationPageState extends State<LSNotificationPage> {
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
        if (lsdata.notifications?.isEmpty ?? true) {
          return const Center(
            child: Text(
              "Keine Benachrichtigungen vorhanden.",
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          itemCount: lsdata.notifications.length,
          itemBuilder: (context, i) {
            final notif = lsdata.notifications[i];
            return Padding(
              padding: (i > 0) ? const EdgeInsets.symmetric(horizontal: 4) : const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
              child: TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                  foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => showDialog(context: context, builder: (ctx) => generateLernSaxNotifInfoDialog(ctx, notif)),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(MdiIcons.clock, size: 16, color: Colors.grey),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(lernSaxTimeFormat.format(notif.date)),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(iconObjectMap[notif.object]),
                        Flexible(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(notif.message),
                        )),
                      ],
                    ),
                    // dont care about group login because no user can recognize that ever
                    if (notif.fromUserName != null || notif.fromGroupName != null || notif.fromUserLogin != null) Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Row(
                        children: [
                          if (notif.hasGroupName) const Icon(MdiIcons.humanMaleBoard),
                          if (notif.hasGroupName) Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text("${notif.fromGroupName}"),
                            ),
                          ),
                          if (notif.hasUserData) const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(MdiIcons.account),
                          ),
                          if (notif.hasUserData) Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text("${notif.fromUserName ?? notif.fromUserLogin}"),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (notif.data != null && !hideData.contains(notif.object)) Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Row(
                        children: [
                          Icon(notif.object == "mail" ? MdiIcons.inboxArrowDown : MdiIcons.formatListText),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(notif.object == "mail" ? "von ${notif.data}" : notif.data!),
                            ),
                          )
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
    super.initState();
    loadData().then((_) {
      // final lsdata = Provider.of<LernSaxData>(context, listen: false);
      // if (lsdata.notifications.isEmpty) {
      //   showDialog(context: context, builder: (context) => AlertDialog(
      //     title: Text("Nachrichten aktivieren?"),
      //     content: Selector<Preferences, bool>(
      //       selector: (_, prefs) => prefs.preferredPronoun == Pronoun.sie,
      //       builder: (context, sie, _) => Text("${sie ? "Sie haben" : "Du hast"} keine Benachrichtungen auf LernSax. "),
      //     ),
      //   ));
      // }
    });
  }

  Future<void> loadData() async {
    setState(() => _loading = true);
    final lsdata = Provider.of<LernSaxData>(context, listen: false);
    final creds = Provider.of<CredentialStore>(context, listen: false);
    lsdata.notifications += (await lernsax.getNotifications(creds.lernSaxLogin, creds.lernSaxToken!, startId: lsdata.notifications.firstOrNull?.id) ?? (){
      // to be run when getNotifications returned null - this is probably bad coding style but idc lol
      showSnackBar(textGen: (sie) => "Fehler beim Abfragen neuer Benachrichtungen. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?", error: true, clear: true);
      return <LSNotification>[];
    }());
    setState(() => _loading = false);
  }

  final iconObjectMap = {
    "files": MdiIcons.fileMultiple,
    "mail": MdiIcons.email,
    "trusts": MdiIcons.login,
    "messenger": MdiIcons.mail,
    "tasks": MdiIcons.checkCircleOutline,
    "board": MdiIcons.bulletinBoard,
  };

  final hideData = ["files", "trusts"];
}

Widget generateLernSaxNotifInfoDialog(BuildContext context, LSNotification notif) {
  return AlertDialog(
    title: const Text("Infos zur Benachrichtigung"),
    content: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoDialogEntry(icon: Icons.numbers, text: "ID: ${notif.id}", paddingTop: EdgeInsets.zero),
          InfoDialogEntry(icon: Icons.access_time_filled, text: lernSaxTimeFormat.format(notif.date)),
          InfoDialogEntry(icon: Icons.info, text: notif.message),
          if (notif.data != null) InfoDialogEntry(icon: MdiIcons.shape, text: notif.data!),
          if (notif.hasUserData) InfoDialogEntry(icon: Icons.person, text: "${notif.fromUserName ?? "Kein Benutzer"}${notif.fromUserLogin != null && notif.fromUserName != notif.fromUserLogin ? " (E-Mail: ${notif.fromUserLogin})" : ""}"),
          if (notif.hasGroupName) InfoDialogEntry(icon: Icons.group_sharp, text: "${notif.fromGroupName ?? "Keine Gruppe"}${notif.fromGroupLogin != null ? " (Login: ${notif.fromGroupLogin})" : ""}"),
          // InfoDialogEntry(icon: Icons.check_box, text: notif.unread ? "Ungelesen" : "Gelesen"),
          InfoDialogEntry(icon: Icons.abc, text: notif.messageTypeId)
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Schließen"))
    ],
  );
}

class InfoDialogEntry extends StatelessWidget {
  final String text;
  final IconData icon;
  final EdgeInsets? paddingTop;
  const InfoDialogEntry({super.key, required this.icon, required this.text, this.paddingTop});

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: paddingTop ?? const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          Flexible(child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(text, maxLines: 10),
          )),
        ],
      ),
    );
    return Flexible(
      child: child
    );
  }
}
