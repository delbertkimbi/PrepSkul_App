# 🔄 Environment Switch Guide

**Switch between Production and Sandbox with ONE line!**

---

## 🎯 **Quick Switch**

### **Step 1: Open Config File**
```
lib/core/config/app_config.dart
```

### **Step 2: Change ONE Line**
```dart
// Line 12 - Change this:
static const bool isProduction = false; // ← false = sandbox, true = production
```

**That's it!** All services automatically switch environments.

---

## 📋 **What Gets Switched**

When you change `isProduction`, these automatically switch:

### **✅ Payment Services**
- Fapshi API URL (sandbox.fapshi.com ↔ live.fapshi.com)
- Fapshi API credentials (sandbox ↔ live)
- Payment processing environment

### **✅ API URLs**
- API Base URL (dev ↔ prod)
- App Base URL
- Web Base URL

### **✅ Database**
- Supabase URL (dev ↔ prod)
- Supabase API keys (dev ↔ prod)

### **✅ Third-Party Services**
- Google Calendar OAuth (dev ↔ prod)
- Fathom AI OAuth (dev ↔ prod)
- Firebase configuration
- Email service (Resend)

---

## 🔍 **How It Works**

### **1. Centralized Config**
All environment configuration is in `AppConfig` class:
```dart
class AppConfig {
  static const bool isProduction = false; // ← Change this
  
  static bool get isProd => isProduction;
  static String get apiBaseUrl => isProd ? 'prod-url' : 'dev-url';
  // ... all other configs
}
```

### **2. Services Use AppConfig**
All services automatically use `AppConfig`:
```dart
// FapshiService
static bool get isProduction => AppConfig.isProd;
static String get _baseUrl => AppConfig.fapshiBaseUrl;

// NotificationHelperService
static String get _apiBaseUrl => AppConfig.apiBaseUrl;
```

### **3. Environment Variables**
The config also reads from `.env` file:
- If `ENVIRONMENT=production` in `.env`, it overrides the flag
- If not set, uses the `isProduction` flag

---

## 📝 **Example Usage**

### **For Development/Testing:**
```dart
// app_config.dart
static const bool isProduction = false; // Sandbox
```

### **For Production:**
```dart
// app_config.dart
static const bool isProduction = true; // Production
```

---

## ⚙️ **Environment Variables**

You can also control via `.env` file:

```bash
# .env file
ENVIRONMENT=production  # or 'development'
```

**Priority:**
1. `.env` file `ENVIRONMENT` variable (if set)
2. `isProduction` flag in code

---

## 🧪 **Testing**

### **Check Current Environment:**
```dart
import 'package:prepskul/core/config/app_config.dart';

// Print current config
AppConfig.printConfig();

// Check environment
if (AppConfig.isProd) {
  print('Running in PRODUCTION');
} else {
  print('Running in SANDBOX');
}
```

### **Verify Services:**
```dart
// Fapshi
print('Fapshi URL: ${FapshiService.isProduction ? "Live" : "Sandbox"}');

// API
print('API URL: ${AppConfig.apiBaseUrl}');
```

---

## 🔐 **Security Notes**

1. **Never commit `.env` files** - They contain secrets
2. **Use different credentials** for dev/prod
3. **Test in sandbox first** before switching to production
4. **Verify all services** after switching environments

---

## 📊 **Current Configuration**

To see current configuration, call:
```dart
AppConfig.printConfig();
```

Output:
```
═══════════════════════════════════════
📱 PrepSkul App Configuration
═══════════════════════════════════════
Environment: 🟢 SANDBOX
API Base URL: https://app.prepskul.com/api
Fapshi Environment: sandbox
Fapshi Base URL: https://sandbox.fapshi.com
Supabase URL: ✅ Set
Firebase: ✅ Set
Google Calendar: ✅ Enabled
Fathom: ✅ Enabled
═══════════════════════════════════════
```

---

## ✅ **Services Updated**

All these services now use `AppConfig`:
- ✅ `FapshiService` - Payment processing
- ✅ `NotificationHelperService` - API URLs
- ✅ All future services will use `AppConfig`

---

**Switch environments with confidence!** 🚀






















