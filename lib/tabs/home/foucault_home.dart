import 'package:flutter/material.dart';
import 'package:kepler_app/tabs/home/home_widget.dart';

class HomePendulumWidget extends StatelessWidget {
  const HomePendulumWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeWidgetBase(
      color: Colors.blue,
      title: Text("Foucaultsches Pendel"),
      child: SizedBox(
        width: 100,
        height: 100,
        child: Placeholder(),
      ),
    );
  }
}
