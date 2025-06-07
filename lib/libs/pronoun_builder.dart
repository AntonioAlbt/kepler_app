import 'package:flutter/material.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:provider/provider.dart';

class PronounBuilder extends StatelessWidget {
  final Widget Function(bool sie) builder;
  const PronounBuilder(this.builder, {super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<Preferences, bool>(builder: (_, sie, _) => builder(sie), selector: (_, prefs) => prefs.preferredPronoun == Pronoun.sie);
  }
}
