import 'package:enough_serialization/enough_serialization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final credentialStore = CredentialStore();

class CredentialStore {
  final _serializer = Serializer();
  final _store = _CredentialStore();
  bool loaded = false;

  String serialize() => _serializer.serialize(_store);
  void loadFromJson(String json) {
    _serializer.deserialize(json, _store);
    loaded = true;
  }
}
class _CredentialStore extends SerializableObject {
  String get lernSaxToken => attributes["lern_sax_token"];
  set lernSaxToken(String token) => attributes["lern_sax_token"] = token;
}

class AppState extends ChangeNotifier {
  /// needed to make current navigation available to the tabs, so they change content based on sub-tab
  List<int> selectedNavigationIndex = [];

  void setNavIndex(String newNavIndex) {
    selectedNavigationIndex = newNavIndex.split(".").map((e) => int.parse(e)).toList();
    notifyListeners();
  }
}
