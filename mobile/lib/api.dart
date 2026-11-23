import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Api {
  String base;
  final Map<String, String> _cookies = {};
  final http.Client client;
  Api(this.base, {http.Client? client}) : client = client ?? http.Client();
  bool get configured => base.isNotEmpty;
  Future<dynamic> request(
    String path, [
    String method = 'GET',
    dynamic data,
  ]) async {
    if (!configured) {
      throw Exception(
        'Connect a backend in Settings / اربط الخادم من الإعدادات',
      );
    }
    String token = '';
    if (method != 'GET') {
      final csrf = await request('csrf/');
      token = csrf['csrfToken'];
    }
    final req = http.Request(method, Uri.parse('$base/api/$path'));
    req.headers['Content-Type'] = 'application/json';
    if (!kIsWeb && _cookies.isNotEmpty) {
      req.headers['Cookie'] = _cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
    }
    if (token.isNotEmpty) req.headers['X-CSRFToken'] = token;
    if (data != null) req.body = jsonEncode(data);
    final res = await http.Response.fromStream(
      await client.send(req).timeout(const Duration(seconds: 25)),
    );
    final cookie = res.headers['set-cookie'];
    if (cookie != null) {
      for (final match in RegExp(
        r'(csrftoken|sessionid)=([^;,]*)',
      ).allMatches(cookie)) {
        _cookies[match.group(1)!] = match.group(2)!;
      }
    }
    final body = res.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      throw Exception(
        body is Map
            ? body['detail'] ?? body.toString()
            : 'HTTP ${res.statusCode}',
      );
    }
    return body;
  }

  Future<void> upload(String path, String field, String filePath) async {
    if (!configured) throw Exception('Connect a backend in Settings');
    final csrf = await request('csrf/');
    final req = http.MultipartRequest('PATCH', Uri.parse('$base/api/$path'));
    req.headers['X-CSRFToken'] = csrf['csrfToken'];
    if (_cookies.isNotEmpty) {
      req.headers['Cookie'] = _cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
    }
    req.files.add(await http.MultipartFile.fromPath(field, filePath));
    final res = await http.Response.fromStream(
      await client.send(req).timeout(const Duration(seconds: 60)),
    );
    if (res.statusCode >= 400) throw Exception('HTTP ${res.statusCode}');
  }

  void close() => client.close();
}
