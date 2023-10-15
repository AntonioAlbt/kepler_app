import 'package:flutter/material.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/main.dart';
import 'package:provider/provider.dart';

/// argument priority: text+error -> textGen+error -> child
void showSnackBar({ String? text, bool error = false, Widget? child, String Function(bool sie)? textGen, bool clear = false, Duration duration = const Duration(seconds: 4) }) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    showSnackBarDirectly(text: text, error: error, child: child, textGen: textGen, clear: clear, duration: duration);
  });
}

void showSnackBarDirectly({ String? text, bool error = false, Widget? child, String Function(bool sie)? textGen, bool clear = false, Duration duration = const Duration(seconds: 4) }) {
  final msgr = ScaffoldMessenger.of(globalScaffoldKey.currentContext!);
  if (clear) msgr.clearSnackBars();
  msgr.showSnackBar(
    SnackBar(
      content: Consumer<Preferences>(
        builder: (context, prefs, _) {
          final errorStyle = TextStyle(color: (prefs.darkTheme) ? Colors.redAccent.shade700 : Colors.redAccent.shade200);
          if (text != null) {
            return Text(
              text,
              style: (error) ? errorStyle : null,
            );
          } else if (textGen != null) {
            return Text(
              textGen(prefs.preferredPronoun == Pronoun.sie),
              style: (error) ? errorStyle : null,
            );
          } else if (child != null) {
            return child;
          } else {
            return const Text("Hallo :)"); // hallo :)
          }
        }
      ),
      duration: duration,
    ),
  );
}
