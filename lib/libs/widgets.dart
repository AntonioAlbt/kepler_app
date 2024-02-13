import 'package:flutter/material.dart';
import 'package:kepler_app/libs/snack.dart';
import 'package:url_launcher/url_launcher.dart';

List<Widget> separatedListViewWithDividers(List<Widget> children)
  => children.fold((0, <Widget>[]), (previousValue, element) {
    final (i, list) = previousValue;
    list.add(element);
    if (i != children.length - 1) list.add(const Divider());
    return (i + 1, list);
  }).$2;


class OpenLinkButton extends StatelessWidget {
  final String label;
  final String link;
  final Icon? infront;
  final Icon? trailing;
  final bool showTrailingIcon;
  const OpenLinkButton({
    super.key, required this.label, required this.link, this.infront, this.trailing, this.showTrailingIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication).catchError((_, __) {
          showSnackBar(text: "Fehler beim Öffnen.");
          return true;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (infront != null) Flexible(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: infront!,
            ),
          ),
          Flexible(flex: 0, child: Text(label)),
          if (showTrailingIcon) Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: trailing ?? const Icon(Icons.open_in_new, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
