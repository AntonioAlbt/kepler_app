import 'package:enough_serialization/enough_serialization.dart';

final prefs = Preferences();

class Preferences extends SerializableObject {
  String get name => attributes['name'];
  set name(String value) => attributes['name'] = value;

  bool get loaded => attributes.isNotEmpty;

  Preferences();
}
