import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const pendelInfoUrl = "https://pendel.vlant.de";
const pendelDataUrl = "https://pendel.vlant.de/logging";

final pendelInfoTabKey = GlobalKey<_PendelInfoTabState>();

void pendelInfoRefreshAction() {
  pendelInfoTabKey.currentState?._load();
}

class PendelInfoTab extends StatefulWidget {
  PendelInfoTab() : super(key: pendelInfoTabKey);

  @override
  State<PendelInfoTab> createState() => _PendelInfoTabState();
}

final pendelDateFormat = DateFormat("dd.MM., hh:mm", "de-DE");

String formatForDisplay(double? num, int precision, [String? suffix, String? orElse])
  => num != null ? ((num * pow(10, precision)).roundToDouble() / pow(10, precision)).toString().replaceAll(".", ",") + (suffix ?? "") : orElse ?? "-";

class _PendelInfoTabState extends State<PendelInfoTab> {
  bool _loading = false, online = false;
  double? cpu, ram, angle, period;
  DateTime? lastUpdate;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (!online) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Selector<Preferences, bool>(
            selector: (_, prefs) => prefs.preferredPronoun == Pronoun.sie,
            builder: (context, sie, _) {
              return Text("Fehler beim Abfragen der Daten. ${sie ? "Sind Sie" : "Bist Du"} mit dem Internet verbunden?");
            }
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text("Die aktuellen Daten des Foucault'schen Pendels an unserer Schule:", style: Theme.of(context).textTheme.bodyLarge),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("Letzte Aktualisierung: ${lastUpdate != null ? pendelDateFormat.format(lastUpdate!) : "unbekannt"}"),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 0),
              child: Column(
                children: [
                  SizedBox(
                    height: 250,
                    child: Stack(
                      alignment: AlignmentDirectional.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.shade100,
                          ),
                          width: 250,
                          height: 250,
                        ),
                        LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints constraints) {
                            final boxWidth = constraints.constrainWidth();
                            const dashWidth = 5.0;
                            const dashHeight = 3.0;
                            final dashCount = (boxWidth / (2 * dashWidth)).floor();
                            return Flex(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              direction: Axis.horizontal,
                              children: List.generate(dashCount, (_) {
                                return const SizedBox(
                                  width: dashWidth,
                                  height: dashHeight,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(color: Colors.grey),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                        Center(
                          child: Transform.rotate(
                            // 180 - x is needed because the data contains the wrong angle and + 90 is needed to change 0° to mean horizontal line
                            angle: (pi / 180.0) * (180 - (angle ?? 0) + 90),
                            child: Container(
                              color: Colors.blue.shade800,
                              width: 5,
                              height: 250,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text("Aktueller Pendel-Winkel: ${formatForDisplay(angle, 2, " °", "unbekannt")}"),
                  ),
                  Text("Aktuelle (berechnete) Zeit pro voller Drehung: ${formatForDisplay(period, 2, " h", "unbekannt")}"),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton(
                onPressed: () => launchUrl(Uri.parse(pendelInfoUrl), mode: LaunchMode.externalApplication).onError((_, __) {
                  showSnackBar(text: "Fehler beim Öffnen.");
                  return false;
                }),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text("Mehr Infos zum Pendel")),
                    Flexible(child: Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.open_in_new, size: 16),
                    ))
                  ],
                ),
              ),
            ),
            if (kDebugFeatures) Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text("Debug-Daten:\n  Systeminfo: CPU: ${formatForDisplay(cpu, 2, " %", "-")}, RAM: ${formatForDisplay(ram, 2, " %", "-")}"),
            ),
            if (kDebugFeatures && (lastUpdate?.year ?? 153000) < 2022) const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Hinweis: Test-Daten - Verbindung zum Server nicht möglich."),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      online = false;
    });

    try {
      final res = jsonDecode((await http.get(Uri.parse(pendelDataUrl))).body);
      cpu = double.tryParse(res["cpu"]);
      ram = double.tryParse(res["ram"]);
      angle = double.tryParse(res["angle"]);
      lastUpdate = DateTime.parse(res["date"]);
      period = double.tryParse(res["period"]);
      online = true;
    } catch (_) {
      if (kDebugFeatures) {
        cpu = double.tryParse("9.31415");
        ram = double.tryParse("15.3092341");
        angle = double.tryParse("66.66666");
        lastUpdate = DateTime.parse(DateTime(2020, 3, 11).toString());
        period = double.tryParse("31");
      }
      // can be simplified, but is better readable this way
      online = kDebugFeatures ? true : false;
    }

    setState(() {
      _loading = false;
    });
  }
}
