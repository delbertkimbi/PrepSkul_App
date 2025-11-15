/**
 * Email Rate Limit Service
 * 
 * Manages email sending rate limits, retries, and cooldown periods
 * to prevent hitting Supabase email rate limits (429 errors)
 */

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class EmailRateLimitService {
  // Rate limit keys
  static const String _keyRateLimitCooldown = 'email_rate_limit_cooldown_';
  static const String _keyLastEmailSent = 'email_last_sent_';
  static const String _keyRetryCount = 'email_retry_count_';
  
  // Rate limit constants
  static const Duration _cooldownPeriod = Duration(minutes: 5);
  static const Duration _minTimeBetweenEmails = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const double _retryBackoffMultiplier = 2.0;
  
  /// Check if user is in cooldown period
  static Future<bool> isInCooldown(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownUntil = prefs.getInt('$_keyRateLimitCooldown$email');
    
    if (cooldownUntil == null) {
      return false;
    }
    
    final cooldownEndTime = DateTime.fromMillisecondsSinceEpoch(cooldownUntil);
    final now = DateTime.now();
    
    if (now.isAfter(cooldownEndTime)) {
      // Cooldown expired, clear it
      await prefs.remove('$_keyRateLimitCooldown$email');
      return false;
    }
    
    return true;
  }
  
  /// Get remaining cooldown time
  static Future<Duration?> getRemainingCooldown(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownUntil = prefs.getInt('$_keyRateLimitCooldown$email');
    
    if (cooldownUntil == null) {
      return null;
    }
    
    final cooldownEndTime = DateTime.fromMillisecondsSinceEpoch(cooldownUntil);
    final now = DateTime.now();
    
    if (now.isAfter(cooldownEndTime)) {
      await prefs.remove('$_keyRateLimitCooldown$email');
      return null;
    }
    
    return cooldownEndTime.difference(now);
  }
  
  /// Set cooldown period for user
  static Future<void> setCooldown(String email, {Duration? duration}) async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownDuration = duration ?? _cooldownPeriod;
    final cooldownEndTime = DateTime.now().add(cooldownDuration);
    
    await prefs.setInt(
      '$_keyRateLimitCooldown$email',
      cooldownEndTime.millisecondsSinceEpoch,
    );
  }
  
  /// Check if enough time has passed since last email
  static Future<bool> canSendEmail(String email) async {
    // Check cooldown first
    if (await isInCooldown(email)) {
      return false;
    }
    
    // Check minimum time between emails
    final prefs = await SharedPreferences.getInstance();
    final lastSent = prefs.getInt('$_keyLastEmailSent$email');
    
    if (lastSent == null) {
      return true;
    }
    
    final lastSentTime = DateTime.fromMillisecondsSinceEpoch(lastSent);
    final now = DateTime.now();
    final timeSinceLastEmail = now.difference(lastSentTime);
    
    return timeSinceLastEmail >= _minTimeBetweenEmails;
  }
  
  /// Record email sent
  static Future<void> recordEmailSent(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_keyLastEmailSent$email',
      DateTime.now().millisecondsSinceEpoch,
    );
    
    // Reset retry count on successful send
    await prefs.remove('$_keyRetryCount$email');
  }
  
  /// Get retry count for email
  static Future<int> getRetryCount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyRetryCount$email') ?? 0;
  }
  
  /// Increment retry count
  static Future<int> incrementRetryCount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = await getRetryCount(email);
    final newCount = currentCount + 1;
    await prefs.setInt('$_keyRetryCount$email', newCount);
    return newCount;
  }
  
  /// Calculate retry delay with exponential backoff
  static Duration calculateRetryDelay(int retryCount) {
    final delaySeconds = _initialRetryDelay.inSeconds * 
        pow(_retryBackoffMultiplier, retryCount);
    return Duration(seconds: delaySeconds.toInt());
  }
  
  /// Check if should retry
  static Future<bool> shouldRetry(String email) async {
    final retryCount = await getRetryCount(email);
    return retryCount < _maxRetries;
  }
  
  /// Clear rate limit data for email (for testing)
  static Future<void> clearRateLimitData(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyRateLimitCooldown$email');
    await prefs.remove('$_keyLastEmailSent$email');
    await prefs.remove('$_keyRetryCount$email');
  }
  
  /// Format cooldown message for user
  static String formatCooldownMessage(Duration remaining) {
    if (remaining.inMinutes > 0) {
      return 'Please wait ${remaining.inMinutes} minute${remaining.inMinutes > 1 ? 's' : ''} before requesting another email.';
    } else {
      return 'Please wait ${remaining.inSeconds} second${remaining.inSeconds > 1 ? 's' : ''} before requesting another email.';
    }
  }
  
  /// Check if error is rate limit error
  static bool isRateLimitError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('rate limit') ||
        errorStr.contains('over_email_send_rate_limit') ||
        errorStr.contains('email rate limit exceeded') ||
        errorStr.contains('429') ||
        errorStr.contains('too_many_requests') ||
        errorStr.contains('too many requests');
  }
}




