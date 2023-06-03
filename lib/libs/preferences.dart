import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/foundation.dart';
import 'package:kepler_app/libs/state.dart';

const prefsPrefKey = "user_preferences";

final prefs = Preferences()
  ..role = Role.unknown
  ..darkTheme = true;

enum Role { teacher, student, parent, other, unknown }

class Preferences extends SerializableObject with ChangeNotifier {
  final _serializer = Serializer();

  Role get role => Role.values.firstWhere((element) => element.name == attributes["role"], orElse: () => Role.unknown);
  set role(Role role) {
    attributes["role"] = role.name;
    notifyListeners();
    save();
  }

  bool get darkTheme => attributes["dark_theme"];
  set darkTheme(bool dt) {
    attributes["dark_theme"] = dt;
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
