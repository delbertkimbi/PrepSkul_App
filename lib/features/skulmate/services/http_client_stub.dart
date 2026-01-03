// Stub file for non-web platforms
import 'package:http/http.dart' as http;

/// Stub for postWeb (mobile platforms)
/// Uses standard http package since CORS is not an issue on mobile
Future<http.Response> postWeb(
  String url,
  Map<String, String> headers,
  String body,
) async {
  return await http.post(
    Uri.parse(url),
    headers: headers,
    body: body,
  );
}

