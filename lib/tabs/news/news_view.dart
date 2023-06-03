import 'package:flutter/material.dart';
import 'package:kepler_app/libs/preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NewsView extends StatefulWidget {
  final Uri newsLink;
  final String newsTitle;

  const NewsView({super.key, required this.newsLink, required this.newsTitle});

  @override
  State<NewsView> createState() => _NewsViewState();
}

class _NewsViewState extends State<NewsView> {
  late final WebViewController _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.newsTitle),
        backgroundColor: (prefs.darkTheme) ? Colors.blueGrey[800] : Colors.blue.shade100,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () => launchUrl(widget.newsLink, mode: LaunchMode.externalApplication),
              child: const Text("Im Browser öffnen"),
            ),
          )
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  @override
  void initState() {
    _controller = WebViewController()
      ..loadRequest(widget.newsLink)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            launchUrlString(
              request.url,
              mode: LaunchMode.externalApplication
            );
            return NavigationDecision.prevent;
          },
          onPageFinished: (url) {
            for (var id in ["secondary", "masthead", "colophon"]) {
              _controller.runJavaScript("document.getElementById(\"$id\").remove();");
            }
            _controller.runJavaScript("document.getElementsByClassName(\"navigation\")[0].remove();");
          },
        ),
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    super.initState();
  }
}
