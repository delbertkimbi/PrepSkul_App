# Splash Screen Navigation Debug Guide

## Current Issue
Splash screen is not navigating to the next screen after initialization.

## Debugging Steps

### 1. Check Console Logs
Look for these log messages in the console:
- `🚀 [SPLASH] Initializing...`
- `🚀 [SPLASH] Starting navigation check...`
- `🔍 [NAV] _navigateToNextScreen() called`
- `🎯 [NAV] Route determined: <route>`
- `✅ [NAV] Navigation executed successfully`

### 2. Check Navigation State
The navigation checks these states:
- `hasCompletedOnboarding` - Has user seen onboarding?
- `isLoggedIn` - Is user logged in (local storage)?
- `hasSupabaseSession` - Does Supabase have a session?
- `hasCompletedSurvey` - Has user completed survey?
- `userRole` - What is the user's role?

### 3. Possible Routes
- `/onboarding` - First time user
- `/auth-method-selection` - Not logged in
- `/profile-setup` - Logged in but survey not completed
- `/tutor-nav` - Tutor dashboard
- `/parent-nav` - Parent dashboard
- `/student-nav` - Student dashboard

### 4. Common Issues

#### Issue 1: Navigation Not Executing
**Symptoms:** No logs from `_navigateToNextScreen()`
**Solution:** Check if `_initializeSplash()` is being called in `initState()`

#### Issue 2: Route Not Found
**Symptoms:** Navigation error or route not registered
**Solution:** Check if routes are properly registered in `main.dart` routes map

#### Issue 3: Context Not Available
**Symptoms:** Navigation fails with context error
**Solution:** Ensure `mounted` check passes before navigation

#### Issue 4: Multiple Navigations
**Symptoms:** Navigation happens multiple times
**Solution:** Check `_hasNavigated` flag is working correctly

## Quick Fix: Add Timeout Navigation

Add this to `_initializeSplash()` method:

```dart
// Force navigation after 3 seconds
Future.delayed(const Duration(seconds: 3), () {
  if (mounted && !_hasNavigated) {
    print('⏰ [SPLASH] TIMEOUT - Forcing navigation');
    _hasNavigated = true;
    Navigator.of(context).pushReplacementNamed('/auth-method-selection');
  }
});
```

## Testing Checklist

- [ ] Check console for splash screen logs
- [ ] Verify routes are registered in main.dart
- [ ] Check if SharedPreferences is working
- [ ] Verify Supabase is initialized
- [ ] Test on different platforms (web, Android, iOS)
- [ ] Check if navigation happens after timeout

## Expected Behavior

1. App starts → Splash screen shows
2. After 1 second → Navigation check starts
3. Route determined → Navigate to appropriate screen
4. If no navigation after 3 seconds → Force navigate to auth

## Next Steps

1. Add more debug logging
2. Check route registration
3. Verify context is available
4. Test timeout navigation
5. Check for silent errors


