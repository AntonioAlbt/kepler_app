import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:provider/provider.dart';

class InfoScreen extends StatefulWidget {
  final Widget? infoImage;
  final Widget? infoTitle;
  final Widget? infoText;
  final Widget? secondaryText;
  final Widget? customScreen;

  final bool closeable;

  const InfoScreen({super.key, this.infoImage, this.infoTitle, this.infoText, this.secondaryText, this.customScreen, this.closeable = true});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  @override
  Widget build(BuildContext context) {
    if (widget.customScreen != null) return widget.customScreen!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.infoImage != null) Padding(
          padding: const EdgeInsets.all(8.0),
          child: widget.infoImage!,
        ),
        if (widget.infoTitle != null) DefaultTextStyle(
          style: Theme.of(context).textTheme.headlineMedium!,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: widget.infoTitle!,
          ),
        ),
        if (widget.infoText != null) Padding(
          padding: const EdgeInsets.all(8),
          child: widget.infoText!,
        ),
        if (widget.infoText == null && widget.infoTitle == null && widget.infoImage == null) const Padding(
          padding: EdgeInsets.all(8),
          child: Text("Keine Daten."),
        )
      ],
    );
  }
}

final infoScreenKey = GlobalKey<_InfoScreenDisplayState>();

class InfoScreenDisplay extends StatefulWidget {
  final List<InfoScreen> infoScreens;

  InfoScreenDisplay({required this.infoScreens}): super(key: infoScreenKey);

  @override
  State<InfoScreenDisplay> createState() => _InfoScreenDisplayState();
}

class _InfoScreenDisplayState extends State<InfoScreenDisplay> with SingleTickerProviderStateMixin {
  late TabController _controller;

  bool canCloseCurrentScreen() {
    return widget.infoScreens[_controller.index].closeable;
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
                    children: widget.infoScreens,
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color.fromRGBO(255, 255, 255, 0.4),
                          borderRadius: BorderRadius.all(Radius.circular(8))
                        ),
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                widget.infoScreens.length,
                                (i) => GestureDetector(
                                  onTap: () => _controller.animateTo(i),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: (_controller.index == i) ? Colors.grey.shade800 : Colors.grey.shade400,
                                        shape: BoxShape.circle
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
                  ),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      if (widget.infoScreens[_controller.index].closeable) {
                        return Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [Colors.white, Color.fromARGB(0, 255, 255, 255)], stops: [0.9, 1])
                              ),
                              child: IconButton(
                                onPressed: state.clearInfoScreen,
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }
                  ),
                ],
              ),
            )
          )
        );
      },
    );
  }

  @override
  void initState() {
    _controller = TabController(length: widget.infoScreens.length, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
