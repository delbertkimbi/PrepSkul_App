# Email Notification Deep Linking

## Current Status

### ✅ What's Working:
1. **Email Templates**: Include `actionUrl` parameters
2. **Email Links**: Use `https://app.prepskul.com${actionUrl}` format
3. **Universal Links Configured**: Android and iOS are configured for `https://app.prepskul.com`
4. **Deep Link Navigation Service**: `NotificationNavigationService` is ready to handle navigation

### ⚠️ What Needs to Be Done:

## 1. Update Email Template Base (Next.js)

**File:** `PrepSkul_Web/lib/email_templates/base_template.ts`

The email template currently uses:
```typescript
<a href="https://app.prepskul.com${actionUrl}" class="button">${actionText}</a>
```

This is correct! Universal links (`https://app.prepskul.com`) will:
- **On Mobile**: Open the app automatically (if universal links are properly configured)
- **On Web**: Open in the web browser

## 2. Add Deep Link Handler in Flutter

**File:** `lib/main.dart`

I've added `app_links: ^6.3.3` to `pubspec.yaml`. Now we need to:

1. Convert `PrepSkulApp` from `StatelessWidget` to `StatefulWidget`
2. Add deep link listener using `AppLinks`
3. Handle incoming links and route using `NotificationNavigationService`

## 3. Universal Links Configuration

### Android (Already Configured ✅)
- `AndroidManifest.xml` has universal link intent filter for `https://app.prepskul.com`

### iOS (Needs Verification)
- Need to add Associated Domains in `ios/Runner.entitlements`:
  ```
  applinks:app.prepskul.com
  ```
- Need to host `apple-app-site-association` file at `https://app.prepskul.com/.well-known/apple-app-site-association`

## 4. How It Works

### Email Flow:
1. User receives email with link: `https://app.prepskul.com/bookings/123`
2. User clicks link in email
3. **Mobile**: Universal link opens the app → `AppLinks` listener catches it → Routes to booking detail
4. **Web**: Opens in browser → Web app handles routing

### Link Format:
- Email links: `https://app.prepskul.com/bookings/123`
- App handles: `/bookings/123` (path only)
- `NotificationNavigationService` parses and navigates

## Next Steps

1. ✅ Add `app_links` package (done)
2. ⏳ Implement deep link handler in `main.dart`
3. ⏳ Test email link clicking on mobile
4. ⏳ Verify universal links work on iOS
5. ⏳ Test on web (should open in browser)

## Testing

To test email deep linking:
1. Send a test notification email
2. Click the action button in the email
3. Verify app opens (mobile) or browser opens (web)
4. Verify navigation goes to correct screen





## Current Status

### ✅ What's Working:
1. **Email Templates**: Include `actionUrl` parameters
2. **Email Links**: Use `https://app.prepskul.com${actionUrl}` format
3. **Universal Links Configured**: Android and iOS are configured for `https://app.prepskul.com`
4. **Deep Link Navigation Service**: `NotificationNavigationService` is ready to handle navigation

### ⚠️ What Needs to Be Done:

## 1. Update Email Template Base (Next.js)

**File:** `PrepSkul_Web/lib/email_templates/base_template.ts`

The email template currently uses:
```typescript
<a href="https://app.prepskul.com${actionUrl}" class="button">${actionText}</a>
```

This is correct! Universal links (`https://app.prepskul.com`) will:
- **On Mobile**: Open the app automatically (if universal links are properly configured)
- **On Web**: Open in the web browser

## 2. Add Deep Link Handler in Flutter

**File:** `lib/main.dart`

I've added `app_links: ^6.3.3` to `pubspec.yaml`. Now we need to:

1. Convert `PrepSkulApp` from `StatelessWidget` to `StatefulWidget`
2. Add deep link listener using `AppLinks`
3. Handle incoming links and route using `NotificationNavigationService`

## 3. Universal Links Configuration

### Android (Already Configured ✅)
- `AndroidManifest.xml` has universal link intent filter for `https://app.prepskul.com`

### iOS (Needs Verification)
- Need to add Associated Domains in `ios/Runner.entitlements`:
  ```
  applinks:app.prepskul.com
  ```
- Need to host `apple-app-site-association` file at `https://app.prepskul.com/.well-known/apple-app-site-association`

## 4. How It Works

### Email Flow:
1. User receives email with link: `https://app.prepskul.com/bookings/123`
2. User clicks link in email
3. **Mobile**: Universal link opens the app → `AppLinks` listener catches it → Routes to booking detail
4. **Web**: Opens in browser → Web app handles routing

### Link Format:
- Email links: `https://app.prepskul.com/bookings/123`
- App handles: `/bookings/123` (path only)
- `NotificationNavigationService` parses and navigates

## Next Steps

1. ✅ Add `app_links` package (done)
2. ⏳ Implement deep link handler in `main.dart`
3. ⏳ Test email link clicking on mobile
4. ⏳ Verify universal links work on iOS
5. ⏳ Test on web (should open in browser)

## Testing

To test email deep linking:
1. Send a test notification email
2. Click the action button in the email
3. Verify app opens (mobile) or browser opens (web)
4. Verify navigation goes to correct screen



# Email Notification Deep Linking

## Current Status

### ✅ What's Working:
1. **Email Templates**: Include `actionUrl` parameters
2. **Email Links**: Use `https://app.prepskul.com${actionUrl}` format
3. **Universal Links Configured**: Android and iOS are configured for `https://app.prepskul.com`
4. **Deep Link Navigation Service**: `NotificationNavigationService` is ready to handle navigation

### ⚠️ What Needs to Be Done:

## 1. Update Email Template Base (Next.js)

**File:** `PrepSkul_Web/lib/email_templates/base_template.ts`

The email template currently uses:
```typescript
<a href="https://app.prepskul.com${actionUrl}" class="button">${actionText}</a>
```

This is correct! Universal links (`https://app.prepskul.com`) will:
- **On Mobile**: Open the app automatically (if universal links are properly configured)
- **On Web**: Open in the web browser

## 2. Add Deep Link Handler in Flutter

**File:** `lib/main.dart`

I've added `app_links: ^6.3.3` to `pubspec.yaml`. Now we need to:

1. Convert `PrepSkulApp` from `StatelessWidget` to `StatefulWidget`
2. Add deep link listener using `AppLinks`
3. Handle incoming links and route using `NotificationNavigationService`

## 3. Universal Links Configuration

### Android (Already Configured ✅)
- `AndroidManifest.xml` has universal link intent filter for `https://app.prepskul.com`

### iOS (Needs Verification)
- Need to add Associated Domains in `ios/Runner.entitlements`:
  ```
  applinks:app.prepskul.com
  ```
- Need to host `apple-app-site-association` file at `https://app.prepskul.com/.well-known/apple-app-site-association`

## 4. How It Works

### Email Flow:
1. User receives email with link: `https://app.prepskul.com/bookings/123`
2. User clicks link in email
3. **Mobile**: Universal link opens the app → `AppLinks` listener catches it → Routes to booking detail
4. **Web**: Opens in browser → Web app handles routing

### Link Format:
- Email links: `https://app.prepskul.com/bookings/123`
- App handles: `/bookings/123` (path only)
- `NotificationNavigationService` parses and navigates

## Next Steps

1. ✅ Add `app_links` package (done)
2. ⏳ Implement deep link handler in `main.dart`
3. ⏳ Test email link clicking on mobile
4. ⏳ Verify universal links work on iOS
5. ⏳ Test on web (should open in browser)

## Testing

To test email deep linking:
1. Send a test notification email
2. Click the action button in the email
3. Verify app opens (mobile) or browser opens (web)
4. Verify navigation goes to correct screen





