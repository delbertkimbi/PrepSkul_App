# 🚀 Quick Test Commands

## Start the App

```bash
# Navigate to project
cd /Users/user/Desktop/PrepSkul/prepskul_app

# Run on Chrome (Web)
flutter run -d chrome

# Run on macOS Desktop
flutter run -d macos

# Run on iOS Simulator (if available)
flutter run -d ios

# Run on Android Emulator (if available)
flutter run -d android
```

## During Development

While app is running:
- Press `r` - Hot reload (fast, keeps state)
- Press `R` - Hot restart (slower, resets state)
- Press `q` - Quit app

## Clean & Rebuild

```bash
# Clean build files
flutter clean

# Get dependencies
flutter pub get

# Run again
flutter run -d chrome
```

## Check for Issues

```bash
# Analyze code
flutter analyze

# Check for linter errors
flutter pub run dart_code_metrics:metrics analyze lib

# Format code
dart format lib
```

## View Logs

```bash
# Run with verbose logging
flutter run -d chrome --verbose

# Or check console output in terminal
```

## Test Specific Features

1. **Post-Trial Dialog:**
   - Login as student
   - Go to "My Requests"
   - Should see dialog if trial is completed

2. **Trial Booking:**
   - Go to "Find Tutors"
   - Select tutor
   - Tap "Book Trial Session"
   - Complete the flow

3. **Conversion Screen:**
   - Complete a trial
   - Tap "Continue with Tutor"
   - Go through 4-step wizard

## Common Issues

**App won't start:**
```bash
flutter clean && flutter pub get && flutter run -d chrome
```

**Hot reload not working:**
- Press `R` for hot restart instead

**Can't see changes:**
- Clear browser cache (Cmd+Shift+Delete)
- Or restart app

**Database errors:**
- Check `.env` file has correct Supabase credentials
- Check Supabase dashboard for connection

