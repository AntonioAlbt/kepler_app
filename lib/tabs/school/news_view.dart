// kepler_app: app for pupils, teachers and parents of pupils of the JKG
// Copyright (c) 2023-2024 Antonio Albert

// This file is part of kepler_app.

// kepler_app is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// kepler_app is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with kepler_app.  If not, see <http://www.gnu.org/licenses/>.

// Diese Datei ist Teil von kepler_app.

// kepler_app ist Freie Software: Sie können es unter den Bedingungen
// der GNU General Public License, wie von der Free Software Foundation,
// Version 3 der Lizenz oder (nach Ihrer Wahl) jeder neueren
// veröffentlichten Version, weiter verteilen und/oder modifizieren.

// kepler_app wird in der Hoffnung, dass es nützlich sein wird, aber
// OHNE JEDE GEWÄHRLEISTUNG, bereitgestellt; sogar ohne die implizite
// Gewährleistung der MARKTFÄHIGKEIT oder EIGNUNG FÜR EINEN BESTIMMTEN ZWECK.
// Siehe die GNU General Public License für weitere Details.

// Sie sollten eine Kopie der GNU General Public License zusammen mit
// kepler_app erhalten haben. Wenn nicht, siehe <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:kepler_app/libs/state.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:share_plus/share_plus.dart';
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
        backgroundColor: (hasDarkTheme(context)) ? Colors.blueGrey[800] : Colors.blue.shade100,
        actions: [
          IconButton(
            icon: Icon(MdiIcons.web),
            onPressed: () => launchUrl(widget.newsLink, mode: LaunchMode.externalApplication),
          ),
          IconButton(
            icon: Icon(MdiIcons.shareVariant),
            onPressed: () => Share.share(widget.newsLink.toString(), sharePositionOrigin: const Rect.fromLTRB(0, 0, 0, 0)),
          ),
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
            if (Uri.parse(request.url) == widget.newsLink) return NavigationDecision.navigate;
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
