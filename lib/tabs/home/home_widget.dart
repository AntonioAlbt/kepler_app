import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/home/home.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

class HomeWidgetBase extends StatelessWidget {
  final Widget child;
  final Widget? title;
  final Color color;
  final Color? titleColor;
  final String? switchId;
  final String id;

  const HomeWidgetBase({super.key, this.title, required this.color, this.titleColor, required this.id, required this.child, this.switchId});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              if (title != null) Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Card(
                  color: titleColor ?? colorWithLightness(color, hasDarkTheme(context) ? .2 : .8),
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: DefaultTextStyle.merge(
                                child: title!,
                                style: Theme.of(context).textTheme.titleMedium,
                                // textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          if (Provider.of<Preferences>(context).showHomeWidgetEditOptions && Provider.of<AppState>(context).userType != UserType.nobody) Align(
                            alignment: AlignmentDirectional.topEnd,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (switchId != null) IconButton(
                                  icon: const Icon(MdiIcons.swapHorizontal, size: 16),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: const Icon(Icons.swap_vert),
                                  onPressed: () => openReorderHomeWidgetDialog(context),
                                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                  iconSize: 20,
                                ),
                                Consumer<Preferences>(
                                  builder: (context, prefs, _) {
                                    return IconButton(
                                      icon: const Icon(MdiIcons.eyeOff),
                                      onPressed: () {
                                        showDialog(context: context, builder: (context) => AlertDialog(
                                          title: const Text("Ausblenden?"),
                                          content: const Text("Dieses Widget wirklich ausblenden? Es ist in den Einstellungen wieder einblendbar."),
                                          actions: [
                                            TextButton(onPressed: () {
                                              prefs.hiddenHomeScreenWidgets = prefs.hiddenHomeScreenWidgets..add(id);
                                              Navigator.pop(context);
                                            }, child: const Text("Ja")),
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Nein")),
                                          ],
                                        ));
                                      },
                                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                      iconSize: 20,
                                    );
                                  }
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
