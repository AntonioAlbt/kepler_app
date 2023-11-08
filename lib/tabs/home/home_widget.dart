import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';
import 'package:kepler_app/libs/state.dart';

class HomeWidgetBase extends StatelessWidget {
  final Widget child;
  final Widget? title;
  final Color color;
  final Color? titleColor;

  const HomeWidgetBase({super.key, this.title, required this.color, this.titleColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              if (title != null) Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Card(
                  color: titleColor ?? colorWithLightness(color, hasDarkTheme(context) ? .2 : .8),
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: DefaultTextStyle.merge(
                        child: title!,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
