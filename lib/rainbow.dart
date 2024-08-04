import 'package:flutter/material.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:provider/provider.dart';
import 'package:rainbow_color/rainbow_color.dart';

const rainbowAnimationDuration = Duration(seconds: 10);

const rainbowColors = [
  Colors.red,
  Colors.orange,
  Colors.yellow,
  Colors.green,
  Colors.blue,
  Colors.purple,
];
final RainbowColorTween rainbowColorTween = RainbowColorTween(const [
  Colors.red,
  Colors.blue,
  Colors.green,
  Colors.yellow,
  Colors.purple,
  Colors.red
]);
final RainbowColorTween darkRainbowColorTween = RainbowColorTween(const [
  Color(0xFFB02D24),
  Color(0xFF145891),
  Color(0xFF2E6B30),
  Color(0xFFBBAC2D),
  Color(0xFF651A72),
  Color(0xFFB02D24)
]);
final RainbowColorTween blueRainbowColorTween = RainbowColorTween([
  Colors.blue.shade600,
  Colors.blue.shade900,
  Colors.blue.shade800,
  Colors.blue.shade700,
  Colors.blue.shade600,
  Colors.blue.shade600
]);

enum RainbowVariant { normal, dark, blue }
final _rainbowMap = {
  RainbowVariant.normal: rainbowColorTween,
  RainbowVariant.dark: darkRainbowColorTween,
  RainbowVariant.blue: blueRainbowColorTween,
};

class RainbowWrapper extends StatelessWidget {
  final Widget Function(BuildContext context, Color? value) builder;
  final RainbowColorTween? rainbow;
  final RainbowVariant? variant;

  const RainbowWrapper({super.key, required this.builder, this.rainbow, this.variant});

  @override
  Widget build(BuildContext context) {
    final animation = rainbow ?? _rainbowMap[variant ?? RainbowVariant.normal]!;
    return RawRainbowWrapper(
      builder: (ctx, val) => builder(ctx, val != null ? animation.lerp(val) : null),
    );
  }
}

class Rainbow2Wrapper extends StatelessWidget {
  final Widget Function(BuildContext context, Color? value1, Color? value2) builder;
  final RainbowColorTween? rainbow1;
  final RainbowColorTween? rainbow2;
  final RainbowVariant? variant1;
  final RainbowVariant? variant2;

  const Rainbow2Wrapper({super.key, required this.builder, this.rainbow1, this.rainbow2, this.variant1, this.variant2});

  @override
  Widget build(BuildContext context) {
    final animation1 = rainbow1 ?? _rainbowMap[variant1 ?? RainbowVariant.normal]!;
    final animation2 = rainbow2 ?? _rainbowMap[variant2 ?? RainbowVariant.normal]!;
    return RawRainbowWrapper(
      builder: (ctx, val) => builder(ctx, val != null ? animation1.lerp(val) : null, val != null ? animation2.lerp(val) : null),
    );
  }
}

class RawRainbowWrapper extends StatelessWidget {
  final Widget Function(BuildContext context, double? value) builder;

  const RawRainbowWrapper({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Selector<Preferences, bool>(
      selector: (ctx, prefs) => prefs.rainbowModeEnabled,
      builder: (context, rainbowModeEnabled, _) {
        if (rainbowModeEnabled) {
          return _RainbowAnimatedWrapper(builder);
        } else {
          return builder(context, null);
        }
      },
    );
  }
}

class _RainbowAnimatedWrapper extends StatefulWidget {
  final Widget Function(BuildContext context, double? value) builder;
  
  const _RainbowAnimatedWrapper(this.builder);

  @override
  State<_RainbowAnimatedWrapper> createState() => __RainbowAnimatedWrapperState();
}

class __RainbowAnimatedWrapperState extends State<_RainbowAnimatedWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value),
    );
  }

  @override
  void initState() {
    _controller = AnimationController(vsync: this, duration: rainbowAnimationDuration);
    _controller.repeat();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
