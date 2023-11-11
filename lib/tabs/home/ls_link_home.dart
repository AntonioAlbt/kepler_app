import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';
import 'package:kepler_app/tabs/lernsax/lernsax.dart';

class HomeLSLinkWidget extends StatelessWidget {
  const HomeLSLinkWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeWidgetBase(
      color: hasDarkTheme(context) ? colorWithLightness(Colors.green, .15) : Colors.green,
      title: const Text("LernSax öffnen"),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: hasDarkTheme(context) ? const Color.fromARGB(255, 10, 36, 11) : Colors.green.shade100, foregroundColor: hasDarkTheme(context) ? Colors.white : const Color.fromARGB(255, 20, 67, 23)),
        onPressed: (){
          lernSaxOpenInBrowser(context);
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("LernSax angemeldet im Browser öffnen"),
            Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.open_in_new, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
