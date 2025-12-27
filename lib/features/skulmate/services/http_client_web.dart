// Web-specific HTTP client using dart:html for proper CORS handling
import 'dart:html' as html;
import 'package:http/http.dart' as http;

/// Web-specific HTTP POST that properly handles CORS with credentials
Future<http.Response> postWeb(
  String url,
  Map<String, String> headers,
  String body,
) async {
  try {
    final request = await html.HttpRequest.request(
      url,
      method: 'POST',
      requestHeaders: headers,
      sendData: body,
      withCredentials: true, // Critical for CORS with Authorization header
    );

    // Convert html.HttpRequest to http.Response
    // Handle null status (shouldn't happen, but be safe)
    final status = request.status ?? 200; // Default to 200 if null (unlikely)
    
    // Convert responseHeaders to Map<String, String>
    // HttpRequest.responseHeaders is already Map<String, String>
    final responseHeaders = Map<String, String>.from(request.responseHeaders);

    return http.Response(
      request.responseText ?? '',
      status,
      headers: responseHeaders,
    );
  } catch (e) {
    // HttpRequest.request throws ProgressEvent on error
    // Extract meaningful error message with better classification
    String errorMessage = 'Failed to fetch';
    String errorType = 'unknown';
    
    if (e is html.ProgressEvent) {
      // ProgressEvent contains error information
      final target = e.target;
      if (target is html.HttpRequest) {
        final status = target.status;
        final statusText = target.statusText ?? '';
        
        if (status != null && status != 0) {
          // HTTP error response received
          if (status >= 500) {
            errorType = 'server';
            errorMessage = 'HTTP $status: Server error - $statusText';
          } else if (status >= 400) {
            errorType = 'client';
            errorMessage = 'HTTP $status: Client error - $statusText';
          } else {
            errorType = 'http';
            errorMessage = 'HTTP $status: $statusText';
          }
        } else {
          // Status 0 usually means CORS error or network error
          // Check if it's likely a CORS issue
          if (status == 0) {
            errorType = 'cors';
            errorMessage = 'CORS blocked or network error (status: 0)';
          } else {
            errorType = 'network';
            errorMessage = 'Network error (status: $status)';
          }
        }
      } else {
        errorType = 'progress';
        errorMessage = 'Request failed: ${e.type}';
      }
    } else {
      errorType = 'exception';
      errorMessage = e.toString();
    }
    
    // Convert to http.ClientException with error type in message
    throw http.ClientException(
      '[$errorType] $errorMessage, uri=$url',
      Uri.parse(url),
    );
  }
}
