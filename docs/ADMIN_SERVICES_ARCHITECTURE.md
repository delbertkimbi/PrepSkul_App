# Admin Services Architecture

**Date:** January 25, 2025

---

## 🎯 **Answer: Admin Services Should Be in Next.js (Admin Dashboard)**

**NOT in the Flutter app!**

---

## 📐 **Architecture Overview**

```
┌─────────────────────────────────────────────────────────┐
│                    PREPSKUL ARCHITECTURE                 │
└─────────────────────────────────────────────────────────┘

┌──────────────────────┐         ┌──────────────────────┐
│   FLUTTER APP        │         │   NEXT.JS APP         │
│   (prepskul_app)     │         │   (PrepSkul_Web)      │
├──────────────────────┤         ├──────────────────────┤
│                      │         │                      │
│ 👥 END USERS:        │         │ 🔧 ADMIN:             │
│ - Students           │         │ - Admin Dashboard     │
│ - Parents            │         │ - Webhook Handlers    │
│ - Tutors             │         │ - API Routes          │
│                      │         │ - Server-side Logic   │
│ ✅ User Features:    │         │                      │
│ - Booking            │         │ ✅ Admin Features:   │
│ - Payments           │         │ - Flag Review        │
│ - Sessions           │         │ - Session Monitoring │
│ - Notifications      │         │ - Analytics           │
│                      │         │ - User Management    │
└──────────────────────┘         └──────────────────────┘
         │                                  │
         └──────────────┬───────────────────┘
                        │
                        ▼
              ┌─────────────────┐
              │   SUPABASE      │
              │   (Database)    │
              └─────────────────┘
```

---

## ✅ **Where Each Service Should Be**

### **Flutter App (prepskul_app)** - End User Features Only

**✅ Should Have:**
- User authentication
- Booking flows
- Payment initiation
- Session viewing
- Notifications (receiving)
- Profile management
- Tutor discovery

**❌ Should NOT Have:**
- Admin flag review
- Admin monitoring
- Admin analytics
- Admin user management
- Admin session analysis

---

### **Next.js App (PrepSkul_Web)** - Admin & Server-Side

**✅ Should Have:**

#### **1. Admin Dashboard** (`/app/admin/`)
- Flag review interface
- Session monitoring dashboard
- User management
- Analytics
- Tutor approval/rejection

#### **2. Webhook Handlers** (`/app/api/webhooks/`)
- Fathom webhook → Analyze transcripts → Create flags
- Fapshi webhook → Update payment status
- Automated flag detection

#### **3. API Routes** (`/app/api/`)
- Admin operations
- Server-side processing
- Secure operations

---

## 🔄 **How Session Monitoring Should Work**

### **Current (Wrong) Architecture:**
```
Flutter App
  └── session_monitoring_service.dart  ❌ WRONG LOCATION
      └── analyzeSessionForFlags()
      └── getAdminFlags()
      └── resolveFlag()
```

### **Correct Architecture:**
```
Next.js Webhook Handler
  └── /app/api/webhooks/fathom/route.ts
      └── Receives Fathom webhook
      └── Calls SessionMonitoringService.analyzeSession()
      └── Creates flags in database

Next.js Admin Dashboard
  └── /app/admin/sessions/flags/page.tsx
      └── Displays flags for review
      └── Allows admins to resolve flags
      └── Shows flag details
```

---

## 📋 **What Needs to Move**

### **From Flutter to Next.js:**

1. **Session Analysis** (`analyzeSessionForFlags`)
   - **Move to:** Next.js webhook handler
   - **When:** Automatically triggered by Fathom webhook
   - **Location:** `/app/api/webhooks/fathom/route.ts`

2. **Flag Retrieval** (`getAdminFlags`)
   - **Move to:** Next.js admin API route
   - **When:** Admin views flags dashboard
   - **Location:** `/app/api/admin/flags/route.ts`

3. **Flag Resolution** (`resolveFlag`)
   - **Move to:** Next.js admin API route
   - **When:** Admin resolves a flag
   - **Location:** `/app/api/admin/flags/[id]/resolve/route.ts`

4. **Admin Notification** (`_notifyAdmins`)
   - **Keep in:** Next.js (already server-side)
   - **When:** Critical flag detected
   - **Location:** Webhook handler or API route

---

## 🚀 **Implementation Plan**

### **Step 1: Move Analysis to Webhook Handler**

**File:** `/Users/user/Desktop/PrepSkul/PrepSkul_Web/app/api/webhooks/fathom/route.ts`

```typescript
// Add after storing transcript
import { analyzeSessionForFlags } from '@/lib/services/session-monitoring';

// In webhook handler:
const flags = await analyzeSessionForFlags({
  sessionId: trialSession.id,
  sessionType: 'trial',
  transcript: transcriptText,
  summary: summaryText,
});
```

### **Step 2: Create Admin Flag Dashboard**

**File:** `/Users/user/Desktop/PrepSkul/PrepSkul_Web/app/admin/sessions/flags/page.tsx`

```typescript
// Display all flags
// Allow filtering by severity
// Show flag details
// Resolve flags
```

### **Step 3: Create API Routes**

**File:** `/Users/user/Desktop/PrepSkul/PrepSkul_Web/app/api/admin/flags/route.ts`
- GET: Fetch all flags
- POST: Create flag (if needed manually)

**File:** `/Users/user/Desktop/PrepSkul/PrepSkul_Web/app/api/admin/flags/[id]/resolve/route.ts`
- POST: Resolve flag with notes

### **Step 4: Remove from Flutter**

**File:** `/Users/user/Desktop/PrepSkul/prepskul_app/lib/features/admin/services/session_monitoring_service.dart`
- **Delete this file** (or move logic to Next.js)

---

## ✅ **Benefits of This Architecture**

1. **✅ Separation of Concerns**
   - Flutter = User features
   - Next.js = Admin features

2. **✅ Security**
   - Admin operations stay server-side
   - No admin code in client app

3. **✅ Automation**
   - Flag detection happens automatically via webhook
   - No manual triggering needed

4. **✅ Better UX**
   - Admins use web dashboard (better for complex tables)
   - Users use mobile app (better for booking)

5. **✅ Scalability**
   - Server-side processing is more efficient
   - Can handle large transcript analysis

---

## 📝 **Summary**

### **Current State:**
- ❌ `session_monitoring_service.dart` is in Flutter app
- ❌ Admin services mixed with user services

### **Correct State:**
- ✅ Session analysis in Next.js webhook handler
- ✅ Flag review in Next.js admin dashboard
- ✅ Flag resolution in Next.js admin API
- ✅ Flutter app only has user-facing features

### **Action Required:**
1. **Move** session monitoring logic to Next.js
2. **Create** admin flag dashboard in Next.js
3. **Create** admin API routes in Next.js
4. **Remove** admin services from Flutter app

---

## 🎯 **Bottom Line**

**Admin services belong in Next.js (admin dashboard), NOT in Flutter app!**

- **Flutter** = For students, parents, tutors (end users)
- **Next.js** = For admins (dashboard, webhooks, API routes)

**The `session_monitoring_service.dart` should be moved to Next.js!** 🚀






