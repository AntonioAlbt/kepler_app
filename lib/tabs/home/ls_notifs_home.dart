import 'package:flutter/material.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';

class HomeLSNotifsWidget extends StatelessWidget {
  const HomeLSNotifsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeWidgetBase(
      color: Colors.blue,
      title: Text("LernSax: Nachrichten"),
      child: SizedBox(
        width: 100,
        height: 100,
        child: Placeholder(),
      ),
    );
  }
}
