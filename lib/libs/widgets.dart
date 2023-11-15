import 'package:flutter/material.dart';

List<Widget> separatedListViewWithDividers(List<Widget> children)
  => children.fold((0, <Widget>[]), (previousValue, element) {
    final (i, list) = previousValue;
    list.add(element);
    if (i != children.length - 1) list.add(const Divider());
    return (i + 1, list);
  }).$2;
