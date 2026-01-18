# 🔒 Database Query Safety - Priority Fix

## 🚨 Critical Issue

**207 uses of `.single()` that can crash the app**

### **The Problem:**

`.single()` throws an error if:
- ❌ **0 rows returned** → "No rows returned"
- ❌ **2+ rows returned** → "Multiple rows returned"

This causes **app crashes** in production!

---

## ✅ The Solution

Replace `.single()` with `.maybeSingle()`:

```dart
// ❌ BAD (current):
final response = await supabase
  .from('table')
  .select()
  .eq('id', id)
  .single(); // Crashes if 0 or 2+ rows!

// ✅ GOOD (safe):
final response = await supabase
  .from('table')
  .select()
  .eq('id', id)
  .maybeSingle(); // Returns null if 0 rows, first row if 1+, no crash!

if (response == null) {
  // Handle not found case
  return null; // or throw appropriate error
}
```

---

## 📊 Impact Assessment

### **High Risk Files (Most Critical):**

1. **`trial_session_service.dart`** - 16 uses
   - Booking flow - users can't book sessions if this crashes
   - **Impact:** 🔴 **CRITICAL**

2. **`booking_service.dart`** - 13 uses
   - Core booking functionality
   - **Impact:** 🔴 **CRITICAL**

3. **`session_payment_service.dart`** - 11 uses
   - Payment processing - money involved!
   - **Impact:** 🔴 **CRITICAL**

4. **`session_lifecycle_service.dart`** - 7 uses
   - Session tracking - core feature
   - **Impact:** 🔴 **CRITICAL**

5. **`individual_session_service.dart`** - 6 uses
   - Session management
   - **Impact:** 🟡 **HIGH**

---

## 🎯 Fix Strategy

### **Phase 1: Critical Services (Day 1)**
- [ ] `trial_session_service.dart` (16 fixes)
- [ ] `booking_service.dart` (13 fixes)
- [ ] `session_payment_service.dart` (11 fixes)
- [ ] `session_lifecycle_service.dart` (7 fixes)

**Total:** 47 critical fixes

### **Phase 2: Important Services (Day 2)**
- [ ] `individual_session_service.dart` (6 fixes)
- [ ] `recurring_session_service.dart` (2 fixes)
- [ ] `session_reschedule_service.dart` (7 fixes)
- [ ] `session_feedback_service.dart` (6 fixes)
- [ ] `fapshi_webhook_service.dart` (3 fixes)

**Total:** 24 important fixes

### **Phase 3: Other Services (Day 3)**
- [ ] Remaining services
- [ ] UI screens
- [ ] Web project

**Total:** ~136 remaining fixes

---

## 🔍 How to Fix

### **Pattern 1: Expecting One Result**

**Before:**
```dart
final session = await supabase
  .from('trial_sessions')
  .select()
  .eq('id', sessionId)
  .single();
```

**After:**
```dart
final session = await supabase
  .from('trial_sessions')
  .select()
  .eq('id', sessionId)
  .maybeSingle();

if (session == null) {
  throw Exception('Session not found: $sessionId');
}
```

---

### **Pattern 2: Optional Result**

**Before:**
```dart
final profile = await supabase
  .from('profiles')
  .select()
  .eq('id', userId)
  .single();
```

**After:**
```dart
final profile = await supabase
  .from('profiles')
  .select()
  .eq('id', userId)
  .maybeSingle();

// Handle null case
if (profile == null) {
  return null; // or create default, or throw specific error
}
```

---

### **Pattern 3: With Error Handling**

**Before:**
```dart
try {
  final result = await supabase
    .from('table')
    .select()
    .eq('id', id)
    .single();
} catch (e) {
  // Generic error handling
}
```

**After:**
```dart
final result = await supabase
  .from('table')
  .select()
  .eq('id', id)
  .maybeSingle();

if (result == null) {
  throw NotFoundException('Record not found: $id');
}
// Use result safely
```

---

## 📋 Testing Checklist

After fixing each file:

- [ ] Test the happy path (record exists)
- [ ] Test the not found case (record doesn't exist)
- [ ] Test edge cases (multiple records - should be prevented by DB constraints)
- [ ] Verify error messages are user-friendly
- [ ] Check logs for proper error handling

---

## 🎯 Priority Order

1. **Payment Services** (money involved - highest priority)
2. **Booking Services** (core functionality)
3. **Session Services** (user experience)
4. **Other Services** (supporting features)

---

## ⚡ Quick Wins

Start with files that have the most uses:
1. `trial_session_service.dart` - 16 fixes
2. `booking_service.dart` - 13 fixes
3. `session_payment_service.dart` - 11 fixes

These 3 files alone = 40 fixes (20% of total)

---

## 📝 Notes

- **Why `.maybeSingle()`?**
  - Returns `null` if 0 rows (no crash)
  - Returns first row if 1+ rows (no crash)
  - We can handle null case explicitly

- **When to use `.limit(1).maybeSingle()`?**
  - If you want to ensure only 1 row is considered
  - Useful when query might return multiple rows but you only need one

- **Database Constraints:**
  - Ideally, DB should prevent duplicates
  - But code should still handle edge cases safely

---

## 🚀 Estimated Time

- **Phase 1 (Critical):** 1 day (47 fixes)
- **Phase 2 (Important):** 1 day (24 fixes)
- **Phase 3 (Remaining):** 2-3 days (136 fixes)

**Total:** 4-5 days for complete fix

**Quick Win:** Fix Phase 1 in 1 day = 47 critical fixes = 23% of total





## 🚨 Critical Issue

**207 uses of `.single()` that can crash the app**

### **The Problem:**

`.single()` throws an error if:
- ❌ **0 rows returned** → "No rows returned"
- ❌ **2+ rows returned** → "Multiple rows returned"

This causes **app crashes** in production!

---

## ✅ The Solution

Replace `.single()` with `.maybeSingle()`:

```dart
// ❌ BAD (current):
final response = await supabase
  .from('table')
  .select()
  .eq('id', id)
  .single(); // Crashes if 0 or 2+ rows!

// ✅ GOOD (safe):
final response = await supabase
  .from('table')
  .select()
  .eq('id', id)
  .maybeSingle(); // Returns null if 0 rows, first row if 1+, no crash!

if (response == null) {
  // Handle not found case
  return null; // or throw appropriate error
}
```

---

## 📊 Impact Assessment

### **High Risk Files (Most Critical):**

1. **`trial_session_service.dart`** - 16 uses
   - Booking flow - users can't book sessions if this crashes
   - **Impact:** 🔴 **CRITICAL**

2. **`booking_service.dart`** - 13 uses
   - Core booking functionality
   - **Impact:** 🔴 **CRITICAL**

3. **`session_payment_service.dart`** - 11 uses
   - Payment processing - money involved!
   - **Impact:** 🔴 **CRITICAL**

4. **`session_lifecycle_service.dart`** - 7 uses
   - Session tracking - core feature
   - **Impact:** 🔴 **CRITICAL**

5. **`individual_session_service.dart`** - 6 uses
   - Session management
   - **Impact:** 🟡 **HIGH**

---

## 🎯 Fix Strategy

### **Phase 1: Critical Services (Day 1)**
- [ ] `trial_session_service.dart` (16 fixes)
- [ ] `booking_service.dart` (13 fixes)
- [ ] `session_payment_service.dart` (11 fixes)
- [ ] `session_lifecycle_service.dart` (7 fixes)

**Total:** 47 critical fixes

### **Phase 2: Important Services (Day 2)**
- [ ] `individual_session_service.dart` (6 fixes)
- [ ] `recurring_session_service.dart` (2 fixes)
- [ ] `session_reschedule_service.dart` (7 fixes)
- [ ] `session_feedback_service.dart` (6 fixes)
- [ ] `fapshi_webhook_service.dart` (3 fixes)

**Total:** 24 important fixes

### **Phase 3: Other Services (Day 3)**
- [ ] Remaining services
- [ ] UI screens
- [ ] Web project

**Total:** ~136 remaining fixes

---

## 🔍 How to Fix

### **Pattern 1: Expecting One Result**

**Before:**
```dart
final session = await supabase
  .from('trial_sessions')
  .select()
  .eq('id', sessionId)
  .single();
```

**After:**
```dart
final session = await supabase
  .from('trial_sessions')
  .select()
  .eq('id', sessionId)
  .maybeSingle();

if (session == null) {
  throw Exception('Session not found: $sessionId');
}
```

---

### **Pattern 2: Optional Result**

**Before:**
```dart
final profile = await supabase
  .from('profiles')
  .select()
  .eq('id', userId)
  .single();
```

**After:**
```dart
final profile = await supabase
  .from('profiles')
  .select()
  .eq('id', userId)
  .maybeSingle();

// Handle null case
if (profile == null) {
  return null; // or create default, or throw specific error
}
```

---

### **Pattern 3: With Error Handling**

**Before:**
```dart
try {
  final result = await supabase
    .from('table')
    .select()
    .eq('id', id)
    .single();
} catch (e) {
  // Generic error handling
}
```

**After:**
```dart
final result = await supabase
  .from('table')
  .select()
  .eq('id', id)
  .maybeSingle();

if (result == null) {
  throw NotFoundException('Record not found: $id');
}
// Use result safely
```

---

## 📋 Testing Checklist

After fixing each file:

- [ ] Test the happy path (record exists)
- [ ] Test the not found case (record doesn't exist)
- [ ] Test edge cases (multiple records - should be prevented by DB constraints)
- [ ] Verify error messages are user-friendly
- [ ] Check logs for proper error handling

---

## 🎯 Priority Order

1. **Payment Services** (money involved - highest priority)
2. **Booking Services** (core functionality)
3. **Session Services** (user experience)
4. **Other Services** (supporting features)

---

## ⚡ Quick Wins

Start with files that have the most uses:
1. `trial_session_service.dart` - 16 fixes
2. `booking_service.dart` - 13 fixes
3. `session_payment_service.dart` - 11 fixes

These 3 files alone = 40 fixes (20% of total)

---

## 📝 Notes

- **Why `.maybeSingle()`?**
  - Returns `null` if 0 rows (no crash)
  - Returns first row if 1+ rows (no crash)
  - We can handle null case explicitly

- **When to use `.limit(1).maybeSingle()`?**
  - If you want to ensure only 1 row is considered
  - Useful when query might return multiple rows but you only need one

- **Database Constraints:**
  - Ideally, DB should prevent duplicates
  - But code should still handle edge cases safely

---

## 🚀 Estimated Time

- **Phase 1 (Critical):** 1 day (47 fixes)
- **Phase 2 (Important):** 1 day (24 fixes)
- **Phase 3 (Remaining):** 2-3 days (136 fixes)

**Total:** 4-5 days for complete fix

**Quick Win:** Fix Phase 1 in 1 day = 47 critical fixes = 23% of total







