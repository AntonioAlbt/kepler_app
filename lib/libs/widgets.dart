import 'package:flutter/material.dart';

// by ChatGPT: https://chat.openai.com/share/17cd40a6-7219-47e6-85e5-35b29366d662
List<Widget> separatedListViewWithDividers(List<Widget> children) {
  // Create an empty list to store the widgets with dividers.
  List<Widget> separatedChildren = [];

  // Loop through the input children list and add each child with a Divider.
  for (int i = 0; i < children.length; i++) {
    // Add the current child.
    separatedChildren.add(children[i]);

    // Add a Divider if this is not the last child.
    if (i < children.length - 1) {
      separatedChildren.add(const Divider());
    }
  }

  // Wrap the separated children in a ListView.
  return separatedChildren;
}
