import 'package:flutter_test/flutter_test.dart';
import 'package:kepler_app/navigation.dart';

void main() {
  test("All Nav page IDs should only contain lowercase letters", () {
    destinations.map((e) => e.id).forEach((element) { expect(RegExp(r"^[a-z]*$").hasMatch(element), true); });
  });
}
