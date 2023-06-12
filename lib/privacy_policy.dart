import 'package:flutter/material.dart';

const privacyPolicyString = """
Wir nutzen deine Daten für absolut alles, genau wie Google oder Facebook.
Tja, schade!

Für legale Zwecke: dies ist nur ein Scherz...
...

















laaanger Text








jooo
""";

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Text(privacyPolicyString),
    );
  }
}
