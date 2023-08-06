import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';

const prefsPrefKey = "user_preferences";

bool? deviceInDarkMode;

enum Pronoun { du, sie }
enum AppTheme { system, dark, light }

class Preferences extends SerializableObject with ChangeNotifier {
  final _serializer = Serializer();

  AppTheme get theme => AppTheme.values.firstWhere((element) => element.name == (attributes["theme"] ?? ""), orElse: () => AppTheme.system);
  set theme(AppTheme theme) {
    attributes["theme"] = theme.name;
    notifyListeners();
    save();
  }
  bool get darkTheme => theme == AppTheme.dark || (theme == AppTheme.system && (deviceInDarkMode ?? true));

  Pronoun get preferredPronoun => Pronoun.values.firstWhere((element) => element.name == (attributes["preferred_pronoun"] ?? ""), orElse: () => Pronoun.du);
  set preferredPronoun(Pronoun pp) {
    attributes["preferred_pronoun"] = pp.name;
    notifyListeners();
    save();
  }

  bool loaded = false;

  save() async {
    sharedPreferences.setString(prefsPrefKey, _serialize());
  }
  String _serialize() => _serializer.serialize(this);
  void loadFromJson(String json) {
    _serializer.deserialize(json, this);
    loaded = true;
  }

  Preferences();
}
