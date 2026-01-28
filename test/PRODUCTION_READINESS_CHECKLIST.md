# Production Readiness Checklist

## Pre-Deployment Verification

### ✅ Code Changes Completed

#### Screen Sharing
- [x] Data stream API implemented for screen sharing notifications
- [x] `onStreamMessage` handler added to receive remote screen sharing events
- [x] `_notifyRemoteUsersScreenSharing()` method sends data stream messages
- [x] Video view switches to `VideoSourceType.videoSourceScreen` when remote user shares
- [x] Rebuild key forces video view update when screen sharing state changes
- [x] All compilation errors fixed

#### Payment Webhook Detection
- [x] Database polling added to `payment_confirmation_screen.dart`
- [x] `_checkDatabaseForWebhookUpdate()` method checks `trial_sessions` and `payment_requests`
- [x] Production mode checks database before API polling
- [x] Success dialog shows immediately when webhook confirms payment
- [x] Both trial and regular payments supported

### ✅ Tests Created

#### Screen Sharing Tests
- [x] `test/features/sessions/screen_sharing_test.dart` - Unit tests
- [x] `test/features/sessions/agora_screen_sharing_integration_test.dart` - Integration tests
- [x] Tests cover data stream messaging, video source switching, error handling

#### Payment Tests
- [x] `test/features/payment/payment_webhook_production_test.dart` - Webhook detection tests
- [x] `test/features/payment/payment_confirmation_screen_test.dart` - Payment confirmation tests
- [x] Tests cover database polling, webhook detection, success dialog

### ✅ Configuration

#### Environment Variables
- [ ] Verify `isProduction = true` in `app_config.dart` for production
- [ ] Verify `API_BASE_URL_PROD = https://www.prepskul.com/api`
- [ ] Verify all required environment variables are set in production

#### Database
- [ ] Verify Supabase RLS policies allow webhook updates
- [ ] Verify `trial_sessions` and `payment_requests` tables are accessible
- [ ] Verify `fapshi_trans_id` column exists in both tables

### ⚠️ Pre-Deployment Testing

#### Screen Sharing
- [ ] Test on two separate devices (not same device)
- [ ] Verify User1's screen content is visible to User2
- [ ] Verify switching between camera and screen works
- [ ] Verify stopping screen sharing returns to camera view
- [ ] Test data stream message delivery

#### Payment Flow
- [ ] Test trial session payment with webhook detection
- [ ] Test regular session payment with webhook detection
- [ ] Verify success dialog appears after webhook confirmation
- [ ] Verify confetti celebration displays
- [ ] Test timeout handling if webhook never arrives

### 📋 Deployment Steps

1. **Set Production Flag**
   ```dart
   // In app_config.dart
   static const bool isProduction = true;
   ```

2. **Verify API URLs**
   - Ensure `API_BASE_URL_PROD` points to `https://www.prepskul.com/api`
   - Verify Next.js API is running on `www.prepskul.com`

3. **Database Configuration**
   - Ensure webhook handler updates `payment_status` to `'paid'`
   - Verify `fapshi_trans_id` is stored correctly

4. **Test Deployment**
   - Deploy to staging first
   - Test screen sharing on staging
   - Test payment flow on staging
   - Verify webhook detection works

5. **Production Deployment**
   - Deploy to production
   - Monitor logs for data stream creation
   - Monitor payment webhook detection
   - Monitor error rates

### 🔍 Monitoring

#### Screen Sharing
- Monitor data stream creation success rate
- Monitor `onStreamMessage` handler execution
- Monitor video source type switching
- Log screen sharing start/stop events

#### Payment
- Monitor database polling frequency
- Monitor webhook detection success rate
- Monitor payment confirmation time
- Log payment status transitions

### 🐛 Known Issues & Workarounds

1. **Data Stream Failure**: If data stream creation fails, screen sharing still works but remote user won't be automatically notified. They can manually detect it by checking video source type.

2. **Webhook Delay**: In production, webhooks may take a few seconds to minutes. Database polling helps detect it faster, but there's still a delay.

3. **Same Device Testing**: Screen sharing may not work correctly when testing on the same device with two browsers due to camera resource conflicts. Always test on separate devices.

### ✅ Final Checklist

- [x] All code changes implemented
- [x] All tests written
- [x] No compilation errors
- [x] No linter errors
- [ ] Tests pass locally
- [ ] Manual testing completed on staging
- [ ] Production environment variables configured
- [ ] Database permissions verified
- [ ] Monitoring set up

## Test Execution

Run all production tests:
```bash
flutter test test/run_production_tests.dart
```

Or run individually:
```bash
# Screen sharing tests
flutter test test/features/sessions/screen_sharing_test.dart
flutter test test/features/sessions/agora_screen_sharing_integration_test.dart

# Payment tests
flutter test test/features/payment/payment_webhook_production_test.dart
flutter test test/features/payment/payment_confirmation_screen_test.dart
```

## Success Criteria

✅ **Screen Sharing**: User1 shares screen → User2 sees screen content (not face)
✅ **Payment Webhook**: Production payments wait for webhook → Success dialog shows
✅ **Payment Flow**: Both trial and regular payments work seamlessly
✅ **Error Handling**: All error cases handled gracefully
✅ **Tests**: All tests pass

