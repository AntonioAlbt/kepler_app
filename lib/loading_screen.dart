import 'package:flutter/material.dart';
import 'package:kepler_app/colors.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

const _withBorder = true;
const _borderWidth = 2.0;

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _circle1AnimContr;
  late final AnimationController _circle2AnimContr;
  late final AnimationController _circle3AnimContr;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        children: [
          Positioned(
            left: 50,
            child: ScaleTransition(
              scale: _circle1AnimContr,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: keplerColorYellow,
                  border:
                      (_withBorder) ? Border.all(width: _borderWidth) : null,
                ),
                width: 200,
                height: 200,
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: 160,
            child: ScaleTransition(
              scale: _circle3AnimContr,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: keplerColorBlue,
                  border:
                      (_withBorder) ? Border.all(width: _borderWidth) : null,
                ),
                width: 115,
                height: 115,
              ),
            ),
          ),
          Positioned(
            top: 110,
            left: 30,
            child: ScaleTransition(
              scale: _circle2AnimContr,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: keplerColorOrange,
                  border:
                      (_withBorder) ? Border.all(width: _borderWidth) : null,
                ),
                width: 140,
                height: 140,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    _circle1AnimContr = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _circle2AnimContr = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _circle3AnimContr = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));

    _circle1AnimContr.addListener(() {
      if (_circle1AnimContr.isCompleted) _circle2AnimContr.forward();
    });
    _circle2AnimContr.addListener(() {
      if (_circle2AnimContr.isCompleted) _circle3AnimContr.forward();
    });
    // _circle3AnimContr.addListener(() {
    //   if (_circle3AnimContr.isCompleted) _circle1AnimContr.forward();
    // });

    _circle1AnimContr.forward();

    super.initState();
  }

  @override
  void dispose() {
    _circle1AnimContr.dispose();
    _circle2AnimContr.dispose();
    _circle3AnimContr.dispose();
    super.dispose();
  }
}
