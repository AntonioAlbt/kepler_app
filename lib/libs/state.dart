import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  /// needed to make current navigation available to the tabs, so they change content based on sub-tab
  List<int> selectedNavigationIndex = [];

  void setNavIndex(String newNavIndex) {
    selectedNavigationIndex = newNavIndex.split(".").map((e) => int.parse(e)).toList();
    notifyListeners();
  }
}
