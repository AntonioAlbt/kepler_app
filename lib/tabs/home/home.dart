import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/home/news_home.dart';
import 'package:kepler_app/tabs/home/stuplan_home.dart';
import 'package:provider/provider.dart';

class HomepageTab extends StatefulWidget {
  const HomepageTab({super.key});

  @override
  State<HomepageTab> createState() => _HomepageTabState();
}

class _HomepageTabState extends State<HomepageTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: HomeNewsWidget(),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: HomeStuPlanWidget(),
              ),
              if (kDebugMode) ElevatedButton(
                onPressed: () {
                  Provider.of<InternalState>(context, listen: false).lastStuPlanAutoReload = null;
                  showSnackBar(text: "is now ${Provider.of<InternalState>(context, listen: false).lastStuPlanAutoReload}");
                },
                child: const Text("Forget todays stuplan reload"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
