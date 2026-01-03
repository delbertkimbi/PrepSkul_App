# 🗺️ Google Maps Integration Setup Guide

**Last Updated:** January 2025

This guide explains how to set up Google Maps integration for onsite and hybrid session location display.

## 🌐 **Web Support**

**Good News:** Web is already supported! 🎉

- ✅ **"View Map" and "Directions" buttons** work perfectly on web (open Google Maps in new tab)
- ✅ **Geocoding** works on web (address → coordinates conversion)
- ✅ **Location permissions** work on web (browser Geolocation API)
- ⏳ **Embedded map widget** - Currently shows placeholder, can be enhanced with Google Maps Embed API (iframe)

**Note:** The `google_maps_flutter` package doesn't support web, but we've implemented web-compatible solutions:
- Web uses Google Maps via URL links (works great!)
- Mobile uses `google_maps_flutter` widget (once API key configured)

---

## 📋 **Requirements**

### **1. Google Cloud Console Setup**

1. **Create/Select Project:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing one

2. **Enable Required APIs:**
   - Navigate to "APIs & Services" > "Library"
   - Enable the following APIs:
     - ✅ **Maps SDK for Android**
     - ✅ **Maps SDK for iOS**
     - ✅ **Geocoding API** (for address to coordinates conversion)

3. **Create API Keys:**
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "API Key"
   - Create **separate keys** for Android and iOS (recommended for security)
   - **Restrict the keys:**
     - **Android Key:** Restrict to "Android apps" and add your package name
     - **iOS Key:** Restrict to "iOS apps" and add your bundle identifier
     - Both: Restrict to only the APIs you enabled above

---

## 🤖 **Android Configuration**

### **Step 1: Add API Key to AndroidManifest.xml**

**File:** `android/app/src/main/AndroidManifest.xml`

Replace `YOUR_GOOGLE_MAPS_API_KEY` with your Android API key:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY" />
```

**Location:** Inside the `<application>` tag, after the `flutterEmbedding` meta-data.

### **Step 2: Verify Permissions**

**File:** `android/app/src/main/AndroidManifest.xml`

Ensure these permissions are present (already added):

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

---

## 🍎 **iOS Configuration**

### **Step 1: Add Google Maps SDK**

**File:** `ios/Podfile`

Add Google Maps to your Podfile (if not already present):

```ruby
pod 'GoogleMaps'
pod 'Google-Maps-iOS-Utils'
```

Then run:
```bash
cd ios
pod install
cd ..
```

### **Step 2: Initialize in AppDelegate**

**File:** `ios/Runner/AppDelegate.swift`

Uncomment and add your iOS API key:

```swift
import GoogleMaps

// In didFinishLaunchingWithOptions:
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

### **Step 3: Verify Permissions**

**File:** `ios/Runner/Info.plist`

Ensure these keys are present (already added):

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>PrepSkul needs your location to show session locations on maps and help you navigate to onsite sessions.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>PrepSkul needs your location to show session locations on maps and help you navigate to onsite sessions.</string>
```

---

## 📦 **Package Installation**

The required packages are already added to `pubspec.yaml`:

```yaml
dependencies:
  google_maps_flutter: ^2.5.0
  geocoding: ^2.1.1
  geolocator: ^11.0.0  # Already installed
```

Run:
```bash
flutter pub get
```

---

## 🔧 **Implementation Status**

### ✅ **What's Implemented:**

1. **Embedded Map Widget** (`embedded_map_widget.dart`)
   - Shows map preview placeholder
   - Geocodes addresses to coordinates
   - Ready for Google Maps integration

2. **Location Display** (`session_location_map.dart`)
   - Shows address and location description
   - Distance calculation
   - Check-in functionality
   - "View Map" and "Directions" buttons (open external maps)

3. **Location Notes Display**
   - Shows landmarks and directions
   - Displayed in session detail screens

### ⏳ **What Needs API Key Configuration:**

1. **Embedded Google Maps Widget**
   - Currently shows placeholder
   - Once API key is configured, uncomment GoogleMap widget code in `embedded_map_widget.dart`
   - Will show interactive map with marker

---

## 🚀 **Activating Embedded Maps**

Once you have your API keys configured:

1. **Update AndroidManifest.xml:**
   - Replace `YOUR_GOOGLE_MAPS_API_KEY` with your Android key

2. **Update AppDelegate.swift:**
   - Uncomment `import GoogleMaps`
   - Uncomment `GMSServices.provideAPIKey(...)`
   - Replace `YOUR_GOOGLE_MAPS_API_KEY` with your iOS key

3. **Activate GoogleMap Widget:**
   - Open `lib/features/sessions/widgets/embedded_map_widget.dart`
   - Uncomment the GoogleMap widget code at the bottom
   - Comment out the placeholder code

4. **Run:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

## 🔐 **Security Best Practices**

1. **Restrict API Keys:**
   - Always restrict keys to specific apps and APIs
   - Use separate keys for Android and iOS
   - Set up key restrictions in Google Cloud Console

2. **Environment Variables (Optional):**
   - Store API keys in `.env` file (not committed to git)
   - Load via `flutter_dotenv` package
   - Use different keys for dev/prod environments

3. **Key Rotation:**
   - Rotate keys periodically
   - Monitor usage in Google Cloud Console
   - Set up billing alerts

---

## 📱 **Permissions**

### **Runtime Permissions:**

The app already handles location permissions at runtime using `geolocator` package:

- ✅ Android: Requests `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`
- ✅ iOS: Requests `NSLocationWhenInUseUsageDescription`

**No additional permission requests needed** - the existing location permission handling covers maps.

---

## 🧪 **Testing**

### **Test Checklist:**

1. ✅ Verify location permissions are requested
2. ✅ Test "View Map" button opens Google Maps
3. ✅ Test "Directions" button opens navigation
4. ✅ Test address geocoding (address → coordinates)
5. ✅ Test embedded map widget (once API key configured)
6. ✅ Test on both Android and iOS devices

---

## 📝 **Current Status**

- ✅ **Location permissions:** Configured
- ✅ **Package dependencies:** Added
- ✅ **Embedded map widget:** Created (placeholder ready)
- ✅ **Geocoding:** Implemented
- ⏳ **Google Maps API keys:** Need to be configured
- ⏳ **Embedded map activation:** Pending API key setup

---

## 🆘 **Troubleshooting**

### **Map not showing:**
- Check API key is correctly set in AndroidManifest.xml / AppDelegate.swift
- Verify APIs are enabled in Google Cloud Console
- Check API key restrictions allow your app
- Ensure billing is enabled (Google Maps requires billing)

### **Geocoding fails:**
- Check internet connection
- Verify Geocoding API is enabled
- Check address format is valid

### **Permissions denied:**
- Check Info.plist / AndroidManifest.xml permissions
- Verify runtime permission requests
- Check device location settings

---

## 📚 **Resources**

- [Google Maps Flutter Plugin](https://pub.dev/packages/google_maps_flutter)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Maps SDK Documentation](https://developers.google.com/maps/documentation)
- [Geocoding API](https://developers.google.com/maps/documentation/geocoding)

---

## ✅ **Next Steps**

1. Get Google Maps API keys from Google Cloud Console
2. Configure keys in AndroidManifest.xml and AppDelegate.swift
3. Uncomment GoogleMap widget code
4. Test embedded maps functionality
5. Monitor API usage and costs

---

**Note:** Google Maps API has usage-based pricing. Monitor your usage in Google Cloud Console and set up billing alerts to avoid unexpected charges.

