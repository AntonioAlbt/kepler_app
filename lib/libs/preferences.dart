import 'package:enough_serialization/enough_serialization.dart';

enum Role { teacher, student, parent, other, unknown }

class Preferences extends SerializableObject {
  Role _role = Role.unknown;
  Role get role => _role;

  bool get loaded => attributes.isNotEmpty;

  void setRole(Role role) {
    _role = role;
  }

  Preferences();
}
