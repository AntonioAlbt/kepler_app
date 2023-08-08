import 'dart:convert';

import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;

const baseUrl = "https://plan.kepler-chemnitz.de/stuplanindiware";
const sUrlD = "$baseUrl/VplanonlineS";
const sUrlM = "$baseUrl/VmobilS";
const lUrlD = "$baseUrl/VplanonlineL";
const lUrlM = "$baseUrl/VmobilL";

final sUrlMKlXmlUrl = Uri.parse("$sUrlM/mobdaten/Klassen.xml");
final lUrlMKlXmlUrl = Uri.parse("$lUrlM/mobdaten/Lehrer.xml");

Future<http.Response> authRequest(Uri url, String user, String password) async
  => http.get(url, headers: {
    "Authorization": "Basic ${base64Encode(utf8.encode("$user:$password"))}"
  });

Future<XmlDocument> _fetch(Uri url, String user, String password) async {
  final res = await authRequest(url, user, password);
  final xml = XmlDocument.parse(res.body);
  return xml;
}

Future<XmlDocument> _getKlassenXML(String user, String password) async {
  final xml = await _fetch(sUrlMKlXmlUrl, user, password);
  return xml;
}

void main() async {
  print((await _fetch(sUrlMKlXmlUrl, "jkgschueler", "jkgplan15")).toXmlString());
}
