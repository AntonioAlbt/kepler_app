import 'package:flutter/material.dart';

List<Widget> separatedListViewWithDividers(List<Widget> children)
  => children.fold(<Widget>[], (previousValue, element) {
    previousValue.add(element);
    previousValue.add(const Divider());
    return previousValue.sublist(0, previousValue.length - 1);
  });
