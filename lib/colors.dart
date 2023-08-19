import 'package:flutter/painting.dart';

const keplerColorYellow = Color(0xFFfed44c);
const keplerColorOrange = Color(0xFFff7c00);
const keplerColorBlue = Color(0xFF4a8aba);

Color colorWithLightness(Color color, double lightness)
  => HSLColor.fromColor(color).withLightness(lightness).toColor();
