# 📱 Notification Flow & Firebase Keys Explained

**Date:** January 2025

---

## 🔄 **How Notifications Work**

### **Complete Flow:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    NOTIFICATION FLOW                            │
└─────────────────────────────────────────────────────────────────┘

1. EVENT OCCURS (Flutter App)
   └─> Booking request created
   └─> Payment received
   └─> Session starting soon

2. FLUTTER APP → NEXT.JS API
   └─> Calls: POST /api/notifications/send
   └─> Sends: userId, type, title, message

3. NEXT.JS API (Server-Side)
   ├─> Creates in-app notification in Supabase ✅
   ├─> Sends email via Resend ✅
   └─> Sends push notification via Firebase Admin SDK ⏳
       └─> Gets FCM tokens from Supabase
       └─> Uses Firebase Admin SDK to send to devices
       └─> Firebase delivers to user's device

4. USER'S DEVICE (Flutter App)
   └─> Receives push notification
   └─> Shows system notification
   └─> Plays sound
   └─> User taps → Opens app → Navigates to content
```

### **Scheduled Notifications:**

```
┌─────────────────────────────────────────────────────────────────┐
│              SCHEDULED NOTIFICATIONS FLOW                       │
└─────────────────────────────────────────────────────────────────┘

1. EVENT OCCURS (Flutter App)
   └─> Trial session booked
   └─> Session scheduled for tomorrow

2. FLUTTER APP → NEXT.JS API
   └─> Calls: POST /api/notifications/schedule-session-reminders
   └─> Schedules: 24-hour reminder, 30-min reminder

3. NEXT.JS API (Server-Side)
   └─> Creates scheduled notifications in Supabase
   └─> Stores: scheduled_for, type, message

4. CRON JOB (Next.js - Runs every 5 minutes)
   └─> Calls: GET /api/cron/process-scheduled-notifications
   └─> Checks: Which notifications are due
   └─> Sends: In-app + Email + Push notifications
   └─> Updates: Status to 'sent'

5. USER'S DEVICE (Flutter App)
   └─> Receives push notification (24 hours before session)
   └─> Receives push notification (30 minutes before session)
```

---

## 🔑 **Firebase Keys Explained**

### **Two Types of Firebase Keys:**

#### **1. Client Keys (Flutter App)** ✅ **YOU ALREADY HAVE THESE**

**Location:** `lib/firebase_options.dart`

**What they are:**
- Public API keys
- Safe to commit to git
- Used by Flutter app to:
  - Initialize Firebase
  - Get FCM tokens
  - Receive push notifications

**Your Client Keys:**
```dart
projectId: 'operating-axis-420213'
apiKey: 'AIzaSyD1UWKHuEPDn81zVjS3zVmfeuLiz2-Sy0g' (web)
apiKey: 'AIzaSyDfLopHRc7cnW-mEqto1CtiwIEk34qGWi4' (Android)
apiKey: 'AIzaSyBn8lnKv4fF-JNKJ8UVe6G1_b3qfwGqKto' (iOS)
messagingSenderId: '613507205446'
```

**Status:** ✅ Already configured, working

---

#### **2. Service Account Key (Next.js Backend)** ⏳ **YOU NEED TO GET THIS**

**Location:** Firebase Console → Project Settings → Service Accounts

**What they are:**
- Private server-side keys
- **NEVER commit to git**
- Used by Next.js API to:
  - Send push notifications to devices
  - Authenticate with Firebase Admin SDK

**Why you need it:**
- Flutter app can RECEIVE push notifications (using client keys) ✅
- Next.js API needs to SEND push notifications (needs service account key) ⏳

**Status:** ⏳ Not yet configured, needed for sending push notifications

---

## 📋 **Where to Get Service Account Key**

### **Step-by-Step Guide:**

1. **Go to Firebase Console**
   - URL: https://console.firebase.google.com/
   - Login with your Google account

2. **Select Your Project**
   - Project: `operating-axis-420213`

3. **Open Project Settings**
   - Click the gear icon (⚙️) next to "Project Overview"
   - Click "Project settings"

4. **Go to Service Accounts Tab**
   - Click on "Service accounts" tab
   - You'll see "Firebase Admin SDK" section

5. **Generate New Private Key**
   - Click "Generate new private key"
   - Confirm by clicking "Generate key"
   - A JSON file will download (e.g., `operating-axis-420213-firebase-adminsdk-xxxxx.json`)

6. **Add to Environment Variables**
   - Open the downloaded JSON file
   - Copy the entire JSON content
   - Add to `.env.local` in Next.js project:

```env
FIREBASE_SERVICE_ACCOUNT_KEY={"type":"service_account","project_id":"operating-axis-420213","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk-xxxxx@operating-axis-420213.iam.gserviceaccount.com","client_id":"...","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"..."}
```

**Important:** 
- The entire JSON must be on ONE line
- All quotes must be properly escaped
- For Vercel: Add as environment variable in Vercel dashboard

---

## 🔒 **Security Notes**

### **Client Keys (Public):**
- ✅ Safe to commit to git
- ✅ Used in Flutter app
- ✅ Can be seen in app code
- ✅ Limited permissions (receive notifications only)

### **Service Account Key (Private):**
- ❌ **NEVER commit to git**
- ❌ **NEVER share publicly**
- ✅ Store in environment variables only
- ✅ Has admin permissions (can send notifications)
- ✅ Add to `.gitignore` if storing as file

---

## ✅ **What You Already Have**

### **Client Keys (Flutter App):**
- ✅ `firebase_options.dart` - Contains all client keys
- ✅ `google-services.json` (Android)
- ✅ `GoogleService-Info.plist` (iOS)
- ✅ Firebase project configured
- ✅ FCM tokens working (Flutter app can receive tokens)

### **Backend (Next.js):**
- ✅ Firebase Admin SDK installed
- ✅ Firebase Admin service created
- ✅ Notification send API ready
- ⏳ **Missing:** Service account key (environment variable)

---

## 🎯 **Summary**

### **Q: Are notifications scheduled in Next.js?**
**A:** Yes! 
- Scheduled notifications are stored in Supabase
- Cron job in Next.js processes them
- Next.js sends push notifications via Firebase Admin SDK
- Flutter app receives and displays them

### **Q: Where do I get the keys?**
**A:** 
- **Client keys:** ✅ Already have them (in `firebase_options.dart`)
- **Service account key:** ⏳ Need to get from Firebase Console (see steps above)

### **Q: Did you give me the keys when publishing?**
**A:** 
- **Client keys:** ✅ Yes, we set up Firebase and got client keys
- **Service account key:** ❌ No, we didn't get it because:
  - It's different from client keys
  - It's only needed for backend (sending notifications)
  - It needs to be generated separately from Firebase Console
  - It's a private key (server-side only)

---

## 🚀 **Next Steps**

1. **Get Service Account Key:**
   - Follow steps above to generate from Firebase Console
   - Download JSON file

2. **Add to Environment Variables:**
   - Add to `.env.local` in Next.js project
   - For Vercel: Add to Vercel environment variables

3. **Test:**
   - Send a test push notification
   - Verify it appears on device
   - Verify sound plays

---

**Once you add the service account key, push notifications will work! 🎉**

