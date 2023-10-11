import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class CustomHueRingPicker extends StatefulWidget {
  const CustomHueRingPicker({
    Key? key,
    required this.pickerColor,
    required this.onColorChanged,
    this.portraitOnly = false,
    this.colorPickerHeight = 250.0,
    this.hueRingStrokeWidth = 20.0,
    this.enableAlpha = false,
    this.displayThumbColor = true,
    this.pickerAreaBorderRadius = const BorderRadius.all(Radius.zero),
  }) : super(key: key);

  final Color pickerColor;
  final ValueChanged<Color> onColorChanged;
  final bool portraitOnly;
  final double colorPickerHeight;
  final double hueRingStrokeWidth;
  final bool enableAlpha;
  final bool displayThumbColor;
  final BorderRadius pickerAreaBorderRadius;

  @override
  State<CustomHueRingPicker> createState() => _CustomHueRingPickerState();
}

class _CustomHueRingPickerState extends State<CustomHueRingPicker> {
  HSVColor currentHsvColor = const HSVColor.fromAHSV(0.0, 0.0, 0.0, 0.0);

  @override
  void initState() {
    currentHsvColor = HSVColor.fromColor(widget.pickerColor);
    super.initState();
  }

  @override
  void didUpdateWidget(CustomHueRingPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    currentHsvColor = HSVColor.fromColor(widget.pickerColor);
  }

  void onColorChanging(HSVColor color) {
    setState(() => currentHsvColor = color);
    widget.onColorChanged(currentHsvColor.toColor());
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).orientation == Orientation.portrait ||
        widget.portraitOnly) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: widget.pickerAreaBorderRadius,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Stack(
                  alignment: AlignmentDirectional.center,
                  children: <Widget>[
                    SizedBox(
                      width: widget.colorPickerHeight,
                      height: widget.colorPickerHeight,
                      child: ColorPickerHueRing(
                        currentHsvColor,
                        onColorChanging,
                        displayThumbColor: widget.displayThumbColor,
                        strokeWidth: widget.hueRingStrokeWidth,
                      ),
                    ),
                    SizedBox(
                      width: widget.colorPickerHeight * .5,
                      height: widget.colorPickerHeight * .5,
                      child: ColorPickerArea(
                          currentHsvColor, onColorChanging, PaletteType.hsv),
                    )
                  ]),
            ),
          ),
          if (widget.enableAlpha)
            SizedBox(
              height: 40.0,
              width: widget.colorPickerHeight,
              child: ColorPickerSlider(
                TrackType.alpha,
                currentHsvColor,
                onColorChanging,
                displayThumbColor: widget.displayThumbColor,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15.0, 5.0, 10.0, 5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ColorIndicator(currentHsvColor),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                    child: ColorPickerInput(
                      currentHsvColor.toColor(),
                      (Color color) {
                        setState(
                            () => currentHsvColor = HSVColor.fromColor(color));
                        widget.onColorChanged(currentHsvColor.toColor());
                      },
                      enableAlpha: widget.enableAlpha,
                      embeddedText: true,
                      disable: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: <Widget>[
          Expanded(
            child: SizedBox(
              width: 300.0,
              height: widget.colorPickerHeight,
              child: ClipRRect(
                borderRadius: widget.pickerAreaBorderRadius,
                child: ColorPickerArea(
                    currentHsvColor, onColorChanging, PaletteType.hsv),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: widget.pickerAreaBorderRadius,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Stack(
                  alignment: AlignmentDirectional.topCenter,
                  children: <Widget>[
                    SizedBox(
                      width: widget.colorPickerHeight -
                          widget.hueRingStrokeWidth * 2,
                      height: widget.colorPickerHeight -
                          widget.hueRingStrokeWidth * 2,
                      child: ColorPickerHueRing(
                          currentHsvColor, onColorChanging,
                          strokeWidth: widget.hueRingStrokeWidth),
                    ),
                    Column(
                      children: [
                        SizedBox(height: widget.colorPickerHeight / 8.5),
                        ColorIndicator(currentHsvColor),
                        const SizedBox(height: 10),
                        Text("#${currentHsvColor.toColor().toString().substring(9, 9+6)}"),
                        if (widget.enableAlpha) const SizedBox(height: 5),
                        if (widget.enableAlpha)
                          SizedBox(
                            height: 40.0,
                            width: (widget.colorPickerHeight -
                                    widget.hueRingStrokeWidth * 2) /
                                2,
                            child: ColorPickerSlider(
                              TrackType.alpha,
                              currentHsvColor,
                              onColorChanging,
                              displayThumbColor: true,
                            ),
                          ),
                      ],
                    ),
                  ]),
            ),
          ),
        ],
      );
    }
  }
}
