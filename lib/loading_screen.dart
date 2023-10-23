import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kepler_app/colors.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

const _withBorder = true;
const _borderWidth = 2.0;

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _circle1AnimContr;
  late AnimationController _circle2AnimContr;
  late AnimationController _circle3AnimContr;
  late AnimationController _textAnimContr;

  Widget? _switcherChild;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 350,
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
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _textAnimContr,
                  child: const Text(
                    "Kepler-App lädt... Bitte warten.",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _switcherChild ?? Opacity(key: UniqueKey(), opacity: 0, child: ElevatedButton(onPressed: () {}, child: const Text(""))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    _circle1AnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _circle2AnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _circle3AnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _textAnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

    _circle1AnimContr.addListener(() {
      if (_circle1AnimContr.isCompleted) _circle2AnimContr.forward();
    });
    _circle2AnimContr.addListener(() {
      if (_circle2AnimContr.isCompleted) _circle3AnimContr.forward();
    });
    _circle3AnimContr.addListener(() {
      if (_circle3AnimContr.isCompleted) {
        Future.delayed(const Duration(milliseconds: 200)).then((_) {
          if (!mounted) return;
          _textAnimContr.repeat(reverse: true, period: const Duration(milliseconds: 700));

          _circle1AnimContr.dispose();
          _circle1AnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 700), upperBound: 1.1, lowerBound: 1);
          _circle1AnimContr.repeat(reverse: true);

          _circle2AnimContr.dispose();
          _circle2AnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 700), upperBound: 1.1, lowerBound: 1);
          _circle2AnimContr.repeat(reverse: true);

          _circle3AnimContr.dispose();
          _circle3AnimContr = AnimationController(vsync: this, duration: const Duration(milliseconds: 700), upperBound: 1.1, lowerBound: 1);
          _circle3AnimContr.repeat(reverse: true);
          setState(() {});
        });
        Future.delayed(const Duration(milliseconds: 2000)).then((_) {
          if (!mounted) return;
          setState(() {
            _switcherChild = ElevatedButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(6, 15, 111, 190)),
              child: const Text("Schließen"),
            );
          });
        });
        Future.delayed(const Duration(seconds: 14)).then((_) {
          if (!mounted) return;
          Sentry.captureException("LoadingError: long loading time, ~ 15s");
        });
        Future.delayed(const Duration(milliseconds: 24050)).then((_) {
          if (!mounted) return;
          Sentry.captureException("LoadingError: extremely long loading time, = 25s");
        });
      }
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
    _textAnimContr.dispose();
    super.dispose();
  }
}
