// Stub HTTP client for non-web platforms
// This file is used when dart.library.html is not available (mobile platforms)
import 'package:http/http.dart' as http;

/// Stub implementation of postWeb for non-web platforms
/// This should never be called in practice since kIsWeb check prevents it,
/// but it's required for compilation on mobile platforms
Future<http.Response> postWeb(
  String url,
  Map<String, String> headers,
  String body,
) async {
  // This should never be reached due to kIsWeb check in _makePostRequest
  // But if it is, fall back to standard http.post
  return await http.post(
    Uri.parse(url),
    headers: headers,
    body: body,
  );
}

