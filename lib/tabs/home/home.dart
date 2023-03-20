import 'package:flutter/material.dart';
import 'package:kepler_app/tabs/home/news_home.dart';

class HomepageTab extends StatefulWidget {
  const HomepageTab({super.key});

  @override
  State<HomepageTab> createState() => _HomepageTabState();
}

class _HomepageTabState extends State<HomepageTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: const [
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: HomeNewsWidget()
            )
          ],
        ),
      ),
    );
  }
}
