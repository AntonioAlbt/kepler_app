import 'package:flutter/material.dart';
import 'package:kepler_app/libs/lernsax.dart' as lernsax;
import 'package:kepler_app/libs/state.dart';
import 'package:provider/provider.dart';

class LSNotificationPage extends StatefulWidget {
  const LSNotificationPage({super.key});

  @override
  State<LSNotificationPage> createState() => _LSNotificationPageState();
}

class _LSNotificationPageState extends State<LSNotificationPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<CredentialStore>(
      builder: (context, creds, child) => FutureBuilder(
        future: lernsax.getNotifications(creds.lernSaxLogin, creds.lernSaxToken!),
        builder: (context, datasn) {
          if (datasn.connectionState != ConnectionState.done) return const Text("loading...");
          if (datasn.hasError) return Text("error: ${datasn.error}");
          return SingleChildScrollView(child: Text(datasn.data?.join(", ") ?? "null???"));
        },
      ),
    );
  }
}
