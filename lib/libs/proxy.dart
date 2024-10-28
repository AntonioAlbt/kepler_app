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

// Some parts of this file are taken from the package platform_proxy (https://pub.dev/packages/platform_proxy).
// This package is licensed under the following license:

// MIT License

// Copyright (c) 2022 Sergey Yamshchikov

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


import 'dart:io';

import 'package:flutter_system_proxy/flutter_system_proxy.dart';
import 'package:kepler_app/libs/logging.dart';

/// Um in Dart (Paket http) alles mögliche zu den verwendeten Clients zu verändern, muss die createHttpClient-
/// Funktion global überschrieben werden, in den HttpOverrides. Dafür wird hier die Klasse erstellt, und dann
/// in main() als Override verwendet.
class ProxyHttpOverrides extends HttpOverrides {
  /// wird bei jeder Verbindung(?) aufgerufen, um einen Client zu erstellen
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    /// Das ist absolut durcheinander, aber scheint leider nötig zu sein, weil man nicht einfach einen "_HttpClient"
    /// intialisieren kann. Also wird:
    final old = HttpOverrides.current; /// (1) das alte Override-Objekt gespeichert
    HttpOverrides.global = null;       /// (2) der aktuelle Override geleert
    final client = HttpClient();       /// (3) ein HttpClient erstellt -> da kein Override da ist, wird ein normaler Client erstellt
    HttpOverrides.global = old;        /// (4) Overrides werden wiederhergestellt
    /// Nur wenn HttpOverrides.createHttpClient global null ist, wird ein normaler HttpClient erstellt - sonst wird
    /// genau diese Funktion hier wieder aufgerufen. -> StackOverflowError
    
    return ProxyAwareHttpClient(client: client)
      ..badCertificateCallback = (cert, host, port) {
        /// Das ist an sich erstmal schlecht, aber bei genauerer Betrachtung zeigt sich... dass es eigentlich
        /// wirklich schlecht ist. Gleichzeitig ist es aber die einzige mir offensichtliche Lösung, da der
        /// Zertifikatsfehler nur alle paar Anfragen auftritt.
        /// Leider ist es trotzdem ziemlich schlecht, da die Anmeldedaten zum Stundenplan halt mit jeder Anfrage
        /// übergeben werden, d.h. wenn jemand den Traffic irgendwie abgreift und ein ungültiges Zertifikat
        /// reinschiebt, könnte man alle Daten komplett abfangen. Aber naja. Ist ja dann doch nur der Stundenplan.
        final ignoredBecauseKPlan = host == "plan.kepler-chemnitz.de";
        logError("http-cert", "cert error for $host:$port${ignoredBecauseKPlan ? " - ignored!" : ""}");
        return ignoredBecauseKPlan;
      };
  }
  /// wird vielleicht auch irgendwo aufgerufen? kann aber leider von mir nicht verwendet werden,
  /// da Dart hier kein async erlaubt und es sich nur damit Proxies von z.B. Android / iOS laden lassen.
  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    /// Immer direct zurückgeben, damit sich der ProxyAwareHttpClient selbst drum kümmern kann.
    return "DIRECT";
  }
}

class ProxyAwareHttpClient implements HttpClient {
  final HttpClient _delegate;
  final Map<String, String> _cache = {};

  ProxyAwareHttpClient({required HttpClient client})
      : _delegate = client {
    _delegate.findProxy = _findProxy as String Function(Uri)?;
  }

  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) =>
      _delegate.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) =>
      _delegate.addProxyCredentials(host, port, realm, credentials);

  @override
  void close({bool force = false}) => _delegate.close(force: force);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) async {
    await resolveProxies(Uri.parse(host));
    return await _delegate.delete(host, port, path);
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) async {
    await resolveProxies(url);
    return await _delegate.deleteUrl(url);
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) async {
    await resolveProxies(Uri.parse(host));
    return await _delegate.get(host, port, path);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    await resolveProxies(url);
    return await _delegate.getUrl(url);
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) async {
    await resolveProxies(Uri.parse(host));
    return await _delegate.head(host, port, path);
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) async {
    await resolveProxies(url);
    return await _delegate.headUrl(url);
  }

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) async {
    await resolveProxies(Uri.parse(host));
    return await _delegate.open(method, host, port, path);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    await resolveProxies(url);
    return await _delegate.openUrl(method, url);
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) async {
    await resolveProxies(Uri.parse(host));
    return await _delegate.patch(host, port, path);
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) async {
    await resolveProxies(url);
    return await _delegate.patchUrl(url);
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) async {
    await resolveProxies(Uri.parse(host));
    return await _delegate.post(host, port, path);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    await resolveProxies(url);
    return await _delegate.postUrl(url);
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) async {
    await resolveProxies(Uri.parse(host));
    return await _delegate.put(host, port, path);
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) async {
    await resolveProxies(url);
    return await _delegate.putUrl(url);
  }

  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _delegate.authenticate = f;

  @override
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String? realm)?
              f) =>
      _delegate.authenticateProxy = f;

  @override
  set badCertificateCallback(
          bool Function(X509Certificate cert, String host, int port)?
              callback) =>
      _delegate.badCertificateCallback = callback;

  @override
  set findProxy(String Function(Uri url)? f) => _delegate.findProxy = f;

  @override
  bool get autoUncompress => _delegate.autoUncompress;

  @override
  set autoUncompress(bool value) => _delegate.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _delegate.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) => _delegate.connectionTimeout = value;

  @override
  Duration get idleTimeout => _delegate.idleTimeout;

  @override
  set idleTimeout(Duration value) => _delegate.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _delegate.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? value) =>
      _delegate.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _delegate.userAgent;

  @override
  set userAgent(String? value) => _delegate.userAgent = value;

  String _findProxy(Uri url) {
    var cacheValue = _cache[url.host];

    if (cacheValue == null) {
      // Naive assumption that it's a redirect of previous request which has to be routed through the same proxy
      /// (Kommentar aus originalem Code)
      /// -> anscheinend wird das nicht neu geladen, wenn eine Redirect stattfindet? Ergibt aber im Schul-Proxy-Setup
      /// auch Sinn, da alle Anfragen aufs öffentliche Internet durch das Proxy durchmüssen
      _cache[url.host] = _cache.values.last;
      cacheValue = _cache[url.host];
    }

    return cacheValue ?? HttpClient.findProxyFromEnvironment(url);
  }

  Future<void> resolveProxies(Uri url) async {
    if (_cache[url.host] != null) {
      return;
    } else {
      var proxy = await FlutterSystemProxy.findProxyFromEnvironment(url.toString());
      _cache[url.host] = proxy;
      return;
    }
  }

  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) {
    _delegate.connectionFactory = f;
  }

  @override
  set keyLog(Function(String line)? callback) {
    _delegate.keyLog = callback;
  }
}
