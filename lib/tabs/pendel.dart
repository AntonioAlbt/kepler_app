import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:kepler_app/build_vars.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
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

class _PendelInfoTabState extends State<PendelInfoTab> with SingleTickerProviderStateMixin {
  bool _loading = false, dataAvailable = false;
  double? cpu, ram, angle, period;
  DateTime? lastUpdate;

  late final AnimationController _controller;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (!dataAvailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
            Text("Die aktuellen Daten des Foucaultschen Pendels an unserer Schule:", style: Theme.of(context).textTheme.bodyLarge),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("Letzte Aktualisierung: ${lastUpdate != null ? pendelDateFormat.format(lastUpdate!) : "unbekannt"}"),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
                child: Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: Stack(
                        alignment: AlignmentDirectional.center,
                        children: [
                          // Container(
                          //   decoration: BoxDecoration(
                          //     shape: BoxShape.circle,
                          //     color: Colors.blue.shade100,
                          //   ),
                          //   width: 250,
                          //   height: 250,
                          // ),
                          Container(
                            decoration: BoxDecoration(
                              color: hasDarkTheme(context) ? colorWithLightness(Colors.grey.shade900, .2) : Colors.grey.shade300,
                            ),
                            width: 350,
                            height: 200,
                          ),
                          SizedBox(
                            width: 300,
                            child: LayoutBuilder(
                              builder: (BuildContext context, BoxConstraints constraints) {
                                final boxWidth = constraints.constrainWidth();
                                const dashWidth = 5.0;
                                const dashHeight = 3.0;
                                final dashCount = (boxWidth / (2 * dashWidth)).floor();
                                return Flex(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  direction: Axis.horizontal,
                                  children: List.generate(dashCount, (_) {
                                    return SizedBox(
                                      width: dashWidth,
                                      height: dashHeight,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(color: hasDarkTheme(context) ? Colors.grey.shade700 : Colors.grey),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ),
                          Center(
                            child: Transform.rotate(
                              // + 90 is needed to change 0° to mean horizontal line
                              angle: (pi / 180.0) * ((angle ?? 0) + 90),
                              child: AnimatedBuilder(
                                animation: _controller,
                                builder: (context, _) {
                                  return Container(
                                    // color: hasDarkTheme(context) ? Colors.blue.shade300 : Colors.blue.shade800,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        stops: [0, max(0, _controller.value - .3), _controller.value, _controller.value + .3, 2],
                                        begin: AlignmentDirectional.topCenter,
                                        end: AlignmentDirectional.bottomCenter,
                                        colors: [Colors.blue.shade300, Colors.blue.shade300, Colors.blue.shade900, Colors.blue.shade300, Colors.blue.shade300],
                                      ),
                                    ),
                                    width: 5,
                                    height: 190,
                                  );
                                }
                              ),
                            ),
                          ),
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: hasDarkTheme(context) ? Colors.white : Colors.black,
                              ),
                              width: 15,
                              height: 3,
                            ),
                          ),
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: hasDarkTheme(context) ? Colors.white : Colors.black,
                              ),
                              width: 3,
                              height: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: "Aktueller Pendel-Winkel: "),
                            TextSpan(
                              text: angle != null ? "${angle!.round()} °" : "unbekannt",
                              style: angle != null ? const TextStyle(fontWeight: FontWeight.bold) : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: "Aktuelle Zeit pro voller Drehung: "),
                          TextSpan(
                            text: formatForDisplay(period, 2, " h", "unbekannt"),
                            style: period != null ? const TextStyle(fontWeight: FontWeight.bold) : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _controller.repeat(reverse: true);
    _autoReload();
  }

  void _autoReload() async {
    if (!mounted) return;
    _load();
    Future.delayed(const Duration(seconds: 30)).then((_) {
      _autoReload();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      dataAvailable = false;
    });

    try {
      final res = jsonDecode((await http.get(Uri.parse(pendelDataUrl))).body);
      // the values should already be double-s, but just to be safe, convert them anyway
      // the api is sometimes unreliable
      cpu = double.tryParse(res["cpu"]?.toString() ?? "-");
      ram = double.tryParse(res["ram"]?.toString() ?? "-");
      angle = double.tryParse(res["angle"]?.toString() ?? "-");
      lastUpdate = DateTime.tryParse(res["date"]?.toString() ?? "-");
      period = double.tryParse(res["period"]?.toString() ?? "-");
      dataAvailable = true;
    } catch (e, s) {
      if (kDebugFeatures) {
        cpu = double.tryParse("9.31415");
        ram = double.tryParse("15.3092341");
        angle = double.tryParse("66.66666");
        lastUpdate = DateTime.parse(DateTime(2020, 3, 11).toString());
        period = double.tryParse("31");
      }
      // can be simplified, but is better readable this way
      dataAvailable = kDebugFeatures ? true : false;
      if (kDebugMode) print("$e - $s");
    }
    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }
}
