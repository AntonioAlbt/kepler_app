import 'package:flutter/material.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';

class HomeLSTasksWidget extends StatelessWidget {
  final String id;

  const HomeLSTasksWidget({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return HomeWidgetBase(
      id: id,
      color: Colors.blue,
      title: const Text("LernSax: Aufgaben"),
      child: const SizedBox(
        width: 100,
        height: 100,
        child: Placeholder(),
      ),
    );
  }
}
