// Web-specific HTTP client using dart:html for proper CORS handling
import 'dart:async';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

/// Web-specific HTTP POST.
/// Returns the response body for all HTTP status codes (including 4xx/5xx)
/// so callers can read API error JSON — unlike [html.HttpRequest.request],
/// which throws on non-2xx before the body is available.
Future<http.Response> postWeb(
  String url,
  Map<String, String> headers,
  String body,
) async {
  final xhr = html.HttpRequest();
  final completer = Completer<http.Response>();

  xhr.open('POST', url, async: true);
  for (final entry in headers.entries) {
    xhr.setRequestHeader(entry.key, entry.value);
  }

  xhr.onLoad.listen((_) {
    if (completer.isCompleted) return;
    completer.complete(
      http.Response(
        xhr.responseText ?? '',
        xhr.status ?? 0,
        headers: Map<String, String>.from(xhr.responseHeaders ?? const {}),
      ),
    );
  });

  xhr.onError.listen((_) {
    if (completer.isCompleted) return;
    completer.completeError(
      http.ClientException('Network error, uri=$url', Uri.parse(url)),
    );
  });

  xhr.onTimeout.listen((_) {
    if (completer.isCompleted) return;
    completer.completeError(
      http.ClientException('Timeout, uri=$url', Uri.parse(url)),
    );
  });

  try {
    xhr.send(body);
  } catch (e) {
    if (!completer.isCompleted) {
      completer.completeError(
        http.ClientException('Request failed: $e, uri=$url', Uri.parse(url)),
      );
    }
  }

  return completer.future;
}
