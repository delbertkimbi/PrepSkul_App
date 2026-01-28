import 'package:http/http.dart' as http;

/// Stub implementation for non-web platforms
/// This file is replaced by http_client_web.dart on web platform
Future<http.Response> postWeb(
  String url,
  Map<String, String> headers,
  String body,
) {
  // This should never be called on non-web platforms
  // The conditional import ensures http_client_web.dart is used on web
  throw UnsupportedError('postWeb is only available on web platform');
}

