import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:provider/provider.dart';

class InfoScreen extends StatefulWidget {
  final Widget? infoImage;
  final Widget? infoTitle;
  final Widget? infoText;
  final Widget? secondaryText;
  final Widget? customScreen;

  final bool closeable;
  final bool Function(int index, BuildContext ctx)? onTryClose;

  const InfoScreen({super.key, this.infoImage, this.infoTitle, this.infoText, this.secondaryText, this.customScreen, this.closeable = true, this.onTryClose});

  @override
  State<InfoScreen> createState() => InfoScreenState();
}

class InfoScreenState extends State<InfoScreen> {
  @override
  Widget build(BuildContext context) {
    if (widget.customScreen != null) return widget.customScreen!;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.infoImage != null) Padding(
              padding: const EdgeInsets.all(8.0),
              child: widget.infoImage!,
            ),
            if (widget.infoTitle != null) DefaultTextStyle(
              style: Theme.of(context).textTheme.headlineSmall!,
              textAlign: TextAlign.center,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: widget.infoTitle!,
              ),
            ),
            if (widget.infoText != null) Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyLarge!,
                textAlign: TextAlign.center,
                child: widget.infoText!,
              ),
            ),
            if (widget.infoText == null && widget.infoTitle == null && widget.infoImage == null) const Padding(
              padding: EdgeInsets.all(8),
              child: Text("Keine Daten."),
            )
          ],
        ),
      ),
    );
  }
}

final infoScreenKey = GlobalKey<InfoScreenDisplayState>();
InfoScreenDisplayState get infoScreenState => infoScreenKey.currentState!;

class InfoScreenDisplay extends StatefulWidget {
  final List<InfoScreen> infoScreens;
  final bool scrollable;

  InfoScreenDisplay({required this.infoScreens, this.scrollable = false}): super(key: infoScreenKey);

  @override
  State<InfoScreenDisplay> createState() => InfoScreenDisplayState();
}

// chatgpt helper function: https://chat.openai.com/share/abec05b9-9556-4909-8eb9-53e69feb17b9
int roundNumberAway(double number, double otherNumber) {
  double difference = number - otherNumber;

  if (difference > 0) {
    return number.ceil();
  } else if (difference < 0) {
    return number.floor();
  } else {
    return number.round();
  }
}

// rounds a number away if its fractional part is further away from the number than tolerance, otherwise rounds it normally
int roundNumberAwayWithTolerance(double number, double awayFrom, double tolerance) {
  if (number % 1 <= tolerance || (1 - number % 1) <= tolerance) return number.round();
  return roundNumberAway(number, awayFrom);
}

class InfoScreenDisplayState extends State<InfoScreenDisplay> with SingleTickerProviderStateMixin {
  late final List<InfoScreen> infoScreens;
  late TabController _controller;

  int get nextOrCurrentIndex => roundNumberAwayWithTolerance(_controller.animation!.value, _controller.index.toDouble(), 0.1);
  int get index => _controller.index;
  void animateTo(int index) => _controller.animateTo(index);
  void next() => animateTo(index + 1);
  void previous() => animateTo(index - 1);

  bool canCloseCurrentScreen() {
    if (!infoScreens[_controller.index].closeable) return infoScreens[_controller.animation!.value.round()].closeable;
    return infoScreens[nextOrCurrentIndex].closeable;
  }

  bool tryCloseCurrentScreen() => canCloseCurrentScreen() && (infoScreens[nextOrCurrentIndex].onTryClose?.call(nextOrCurrentIndex, context) ?? true);

  void updateInfoScreens(List<InfoScreen> updatedInfoScreens) {
    _controller.dispose();
    setState(() {
      infoScreens = updatedInfoScreens;
      _controller = TabController(length: updatedInfoScreens.length, vsync: this);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 100),
          child: Scaffold(
            key: const Key("1"),
            body: Container(
              padding: MediaQuery.of(context).padding,
              color: Theme.of(context).colorScheme.background,
              child: Stack(
                children: [
                  TabBarView(
                    controller: _controller,
                    physics: (!widget.scrollable) ? const NeverScrollableScrollPhysics() : null,
                    children: infoScreens,
                  ),
                  if (kDebugMode) Align(
                    alignment: Alignment.topRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          onPressed: () => infoScreenState.previous(),
                          backgroundColor: Colors.red.shade800,
                          child: const Icon(Icons.arrow_back),
                        ),
                        FloatingActionButton.small(
                          onPressed: () => infoScreenState.next(),
                          backgroundColor: Colors.red.shade800,
                          child: const Icon(Icons.arrow_forward),
                        ),
                      ],
                    ),
                  ),
                  KeyboardVisibilityBuilder(
                    builder: (context, keyboardHidden) {
                      if (keyboardHidden) return const SizedBox.shrink();
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.background.withOpacity(0.5),
                              borderRadius: const BorderRadius.all(Radius.circular(8))
                            ),
                            child: Selector<Preferences, bool>(
                              selector: (ctx, prefs) => prefs.darkTheme,
                              builder: (context, dark, __) {
                                return AnimatedBuilder(
                                  animation: _controller.animation!,
                                  builder: (context, _) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      infoScreens.length,
                                      (i) => GestureDetector(
                                        // onTap: () => _controller.animateTo(i),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: (_controller.animation!.value.round() == i) ? Colors.grey[(dark) ? 200 : 800] : Colors.grey[(dark) ? 600 : 400],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                            ),
                          ),
                        ),
                      );
                    }
                  ),
                  AnimatedBuilder(
                    animation: _controller.animation!,
                    builder: (context, _) => AnimatedOpacity(
                      duration: const Duration(milliseconds: 100),
                      opacity: canCloseCurrentScreen() ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !canCloseCurrentScreen(),
                        child: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                // gradient: RadialGradient(colors: [Theme.of(context).colorScheme.background, Theme.of(context).colorScheme.background.withAlpha(0)], stops: const [0.9, 1]),
                                border: Border.all(color: Theme.of(context).highlightColor, width: 1.5),
                                color: Theme.of(context).colorScheme.background.withOpacity(0.5)
                              ),
                              child: IconButton(
                                padding: const EdgeInsets.all(5),
                                visualDensity: const VisualDensity(horizontal: -2.0, vertical: -1.5),
                                onPressed: () {
                                  if (tryCloseCurrentScreen()) state.clearInfoScreen();
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        );
      },
    );
  }

  @override
  void initState() {
    infoScreens = widget.infoScreens;
    _controller = TabController(length: infoScreens.length, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
