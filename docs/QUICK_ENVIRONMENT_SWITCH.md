# ⚡ Quick Environment Switch

## 🔄 **Switch in ONE Line**

**File:** `lib/core/config/app_config.dart`  
**Line:** 12

```dart
// SANDBOX (Development/Testing)
static const bool isProduction = false;

// PRODUCTION (Live)
static const bool isProduction = true;
```

---

## ✅ **What Switches Automatically**

- ✅ Fapshi Payment API (sandbox ↔ live)
- ✅ API URLs (dev ↔ prod)
- ✅ Supabase (dev ↔ prod)
- ✅ Google Calendar OAuth (dev ↔ prod)
- ✅ Fathom AI OAuth (dev ↔ prod)
- ✅ All service credentials

---

## 🧪 **Check Current Environment**

```dart
import 'package:prepskul/core/config/app_config.dart';

AppConfig.printConfig();
```

---

**That's it!** 🚀


