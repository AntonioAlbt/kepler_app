import 'package:flutter/material.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';

class HomeLSMailsWidget extends StatelessWidget {
  final String id;

  const HomeLSMailsWidget({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return HomeWidgetBase(
      id: id,
      color: Colors.blue,
      title: const Text("LernSax: E-Mails"),
      child: const SizedBox(
        width: 100,
        height: 100,
        child: Placeholder(),
      ),
    );
  }
}
