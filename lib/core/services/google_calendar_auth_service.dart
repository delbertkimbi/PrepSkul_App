import 'package:google_sign_in/google_sign_in.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:googleapis_auth/auth_io.dart' as auth_io;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Google Calendar Authentication Service
///
/// Handles OAuth2 authentication for Google Calendar API
/// Stores and refreshes access tokens securely
class GoogleCalendarAuthService {
  static const String _prefsKeyAccessToken = 'google_calendar_access_token';
  static const String _prefsKeyRefreshToken = 'google_calendar_refresh_token';
  static const String _prefsKeyTokenExpiry = 'google_calendar_token_expiry';

  // Scopes required for Calendar API
  // Note: 'calendar' scope includes 'calendar.events', so we only need 'calendar'
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/calendar', // This includes calendar.events
  ];

  /// Sign in with Google and request Calendar permissions
  ///
  /// Returns true if authentication successful, false otherwise
  static Future<bool> signIn() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: _scopes,
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        LogService.warning('Google Sign-In cancelled by user');
        return false;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      if (auth.accessToken == null) {
        LogService.error('No access token received from Google Sign-In');
        return false;
      }

      // Store tokens
      // Note: GoogleSignIn doesn't provide refreshToken directly
      // We'll rely on GoogleSignIn's built-in token refresh
      await _storeTokens(
        accessToken: auth.accessToken!,
        refreshToken: null, // GoogleSignIn handles refresh internally
        expiresIn: 3600, // Default 1 hour
      );

      LogService.success('Google Calendar authentication successful');
      return true;
    } catch (e) {
      LogService.error('Error signing in to Google Calendar: $e');
      return false;
    }
  }

  /// Check if user is already authenticated
  static Future<bool> isAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_prefsKeyAccessToken);
      final expiryTimestamp = prefs.getInt(_prefsKeyTokenExpiry);

      if (accessToken == null || expiryTimestamp == null) {
        return false;
      }

      // Check if token is expired
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now >= expiryTimestamp) {
        // Try to refresh token
        return await refreshToken();
      }

      return true;
    } catch (e) {
      LogService.error('Error checking authentication status: $e');
      return false;
    }
  }

  /// Get authenticated HTTP client for Calendar API
  ///
  /// Returns null if not authenticated or token refresh fails
  static Future<http.Client?> getAuthenticatedClient() async {
    try {
      if (!await isAuthenticated()) {
        LogService.warning('Not authenticated with Google Calendar');
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_prefsKeyAccessToken);

      if (accessToken == null) {
        return null;
      }

      // Create authenticated client using the access token
      final credentials = auth_io.AccessCredentials(
        auth_io.AccessToken('Bearer', accessToken, DateTime.now().add(Duration(hours: 1))),
        null, // Refresh token not available from GoogleSignIn
        _scopes,
      );

      // Create authenticated client
      final client = auth_io.authenticatedClient(
        http.Client(),
        credentials,
      );

      return client;
    } catch (e) {
      LogService.error('Error getting authenticated client: $e');
      return null;
    }
  }

  /// Refresh access token using refresh token
  static Future<bool> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_prefsKeyRefreshToken);

      if (refreshToken == null) {
        LogService.warning('No refresh token available');
        return false;
      }

      // Use Google Sign-In to refresh token
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: _scopes,
      );

      // Try to sign in silently (uses existing session)
      final GoogleSignInAccount? account = await googleSignIn.signInSilently();
      if (account == null) {
        LogService.warning('Silent sign-in failed, user needs to re-authenticate');
        return false;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      if (auth.accessToken == null) {
        return false;
      }

      // Store new tokens
      await _storeTokens(
        accessToken: auth.accessToken!,
        refreshToken: refreshToken, // Keep existing refresh token if available
        expiresIn: 3600,
      );

      LogService.success('Access token refreshed');
      return true;
    } catch (e) {
      LogService.error('Error refreshing token: $e');
      return false;
    }
  }

  /// Sign out from Google Calendar
  static Future<void> signOut() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: _scopes,
      );
      await googleSignIn.signOut();

      // Clear stored tokens
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyAccessToken);
      await prefs.remove(_prefsKeyRefreshToken);
      await prefs.remove(_prefsKeyTokenExpiry);

      LogService.success('Signed out from Google Calendar');
    } catch (e) {
      LogService.error('Error signing out: $e');
    }
  }

  /// Store tokens securely
  static Future<void> _storeTokens({
    required String accessToken,
    String? refreshToken,
    required int expiresIn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyAccessToken, accessToken);
    
    if (refreshToken != null) {
      await prefs.setString(_prefsKeyRefreshToken, refreshToken);
    }

    // Calculate expiry timestamp (current time + expiresIn seconds)
    final expiryTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expiresIn;
    await prefs.setInt(_prefsKeyTokenExpiry, expiryTimestamp);
  }

  /// Get stored access token (for direct API calls if needed)
  static Future<String?> getAccessToken() async {
    try {
      if (!await isAuthenticated()) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefsKeyAccessToken);
    } catch (e) {
      LogService.error('Error getting access token: $e');
      return null;
    }
  }
}
