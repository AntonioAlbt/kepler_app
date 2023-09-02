import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:provider/provider.dart';

class LernSaxTab extends StatefulWidget {
  const LernSaxTab({super.key});

  @override
  State<LernSaxTab> createState() => _LernSaxTabState();
}

class _LernSaxTabState extends State<LernSaxTab> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Consumer<CredentialStore>(
        builder: (context, creds, _) {
          return Text(
            "${creds.lernSaxLogin}\n\nHochsicheres Token!!! -> ${creds.lernSaxToken}"
          );
        }
      ),
    );
  }
}
