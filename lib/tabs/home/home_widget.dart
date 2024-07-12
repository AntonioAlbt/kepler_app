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
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/rainbow.dart';
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
  final bool? overrideShowIcons;

  const HomeWidgetBase({super.key, this.title, required this.color, this.titleColor, required this.id, required this.child, this.switchId, this.overrideShowIcons});

  @override
  Widget build(BuildContext context) {
    return Rainbow2Wrapper(
      variant2: RainbowVariant.dark,
      builder: (context, rcolor, rcolorTitle) {
        final titleColor = this.titleColor ?? colorWithLightness(color, hasDarkTheme(context) ? .2 : .8);
        return Card(
          color: rcolor != null ? Color.alphaBlend(rcolor.withOpacity(.4), color) : color,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  if (title != null) Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Card(
                      color: rcolorTitle != null ? Color.alphaBlend(rcolorTitle.withOpacity(.4), titleColor) : titleColor,
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
                              if (Provider.of<Preferences>(context).showHomeWidgetEditOptions && Provider.of<AppState>(context).userType != UserType.nobody && overrideShowIcons != false) Align(
                                alignment: AlignmentDirectional.topEnd,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (switchId != null) IconButton(
                                      icon: Icon(MdiIcons.swapHorizontal, size: 16),
                                      onPressed: () {},
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.swap_vert),
                                      onPressed: () => openReorderHomeWidgetDialog(),
                                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                      iconSize: 20,
                                    ),
                                    Consumer<Preferences>(
                                      builder: (context, prefs, _) {
                                        return IconButton(
                                          icon: Icon(MdiIcons.eyeOff),
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
    );
  }
}
