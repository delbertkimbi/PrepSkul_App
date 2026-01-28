# Test Execution Guide for Production Deployment

## Quick Start

Run all production-related tests:
```bash
flutter test test/run_production_tests.dart
```

## Individual Test Suites

### Screen Sharing Tests
```bash
# Unit tests
flutter test test/features/sessions/screen_sharing_test.dart

# Integration tests
flutter test test/features/sessions/agora_screen_sharing_integration_test.dart
```

### Payment Tests
```bash
# Webhook detection tests
flutter test test/features/payment/payment_webhook_production_test.dart

# Payment confirmation tests
flutter test test/features/payment/payment_confirmation_screen_test.dart

# Production payment simulation
flutter test test/features/payment/payment_simulation_production_test.dart
```

## Test Coverage Summary

### Screen Sharing (2 test files, ~25 tests)
- ✅ Video source type detection
- ✅ Data stream message handling
- ✅ Remote screen sharing detection
- ✅ Video view source switching
- ✅ Error handling
- ✅ Production readiness

### Payment Webhook (2 test files, ~30 tests)
- ✅ Database polling logic
- ✅ Trial session webhook detection
- ✅ Regular payment webhook detection
- ✅ Production vs sandbox modes
- ✅ Transaction ID parsing
- ✅ Error handling
- ✅ Success dialog display

## Expected Test Results

All tests should pass with:
- ✅ 0 failures
- ✅ 0 errors
- ✅ All assertions pass

## Troubleshooting

If tests fail:
1. Check that all dependencies are installed: `flutter pub get`
2. Verify Agora SDK is properly configured
3. Check that test files compile: `flutter analyze test/`
4. Review test output for specific error messages

## Pre-Deployment Verification

Before deploying to production:
1. ✅ All tests pass
2. ✅ No compilation errors
3. ✅ No linter warnings
4. ✅ Manual testing completed
5. ✅ Production environment variables set

