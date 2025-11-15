# 📱 Offline Experience Guide

**Last Updated:** January 2025

---

## 🎯 **Overview**

PrepSkul provides a great offline experience for both students/parents and tutors. When logged in but offline, users can still access cached data and view their information, even though they can't perform actions that require internet connectivity.

---

## ✅ **What Users Can Do Offline**

### **For Students/Parents:**

1. **View Cached Tutor Lists**
   - Browse previously loaded tutors from discovery
   - See tutor profiles, ratings, subjects, pricing
   - View tutor details (bio, certifications, teaching style)
   - **Note:** Can't search for new tutors or apply filters

2. **View Booking Requests**
   - See all their booking requests (pending, approved, rejected)
   - View request details (schedule, payment plan, tutor info)
   - See request status and tutor responses
   - **Note:** Can't create new requests or approve/reject

3. **View Sessions**
   - See upcoming sessions (recurring and individual)
   - View session details (date, time, location, tutor)
   - See session history
   - **Note:** Can't start/end sessions or join meetings

4. **View Profile**
   - See their profile information
   - View learning information (subjects, skills, goals)
   - **Note:** Can't edit profile or upload photos

5. **View Notifications**
   - See previously loaded notifications
   - **Note:** Can't receive new notifications

### **For Tutors:**

1. **View Booking Requests**
   - See all booking requests (pending, approved, rejected)
   - View request details (student info, schedule, payment)
   - See request status and their responses
   - **Note:** Can't approve/reject requests

2. **View Sessions**
   - See upcoming sessions (recurring and individual)
   - View session details (date, time, location, student)
   - See session history
   - **Note:** Can't start/end sessions or generate Meet links

3. **View Students**
   - See list of their students
   - View student profiles and progress
   - **Note:** Can't update student information

4. **View Profile**
   - See their profile information
   - View certifications, subjects, availability
   - **Note:** Can't edit profile or upload documents

5. **View Notifications**
   - See previously loaded notifications
   - **Note:** Can't receive new notifications

---

## ❌ **What Users CANNOT Do Offline**

### **Actions Requiring Internet:**

1. **Authentication**
   - Can't log in or sign up
   - Can't reset password
   - Can't verify email/phone

2. **Data Fetching**
   - Can't search for new tutors
   - Can't apply filters to tutor discovery
   - Can't fetch new booking requests
   - Can't fetch new sessions

3. **Actions**
   - Can't create booking requests
   - Can't approve/reject requests
   - Can't start/end sessions
   - Can't make payments
   - Can't send messages
   - Can't submit feedback

4. **Updates**
   - Can't edit profile
   - Can't upload photos/documents
   - Can't update availability
   - Can't update session status

---

## 🔄 **How It Works**

### **Caching Strategy:**

1. **Automatic Caching**
   - All data fetched from Supabase is automatically cached locally
   - Cache is stored in SharedPreferences (JSON format)
   - Cache expires after 7 days

2. **Offline Detection**
   - App monitors connectivity using `connectivity_plus`
   - Shows offline indicator when disconnected
   - Automatically serves from cache when offline

3. **Cache Refresh**
   - When back online, app fetches fresh data
   - Cache is updated with latest data
   - User sees updated information

### **Cache Storage:**

- **Tutor Lists:** Cached when browsing discovery
- **Tutor Details:** Cached when viewing tutor profile
- **Booking Requests:** Cached when viewing requests screen
- **Sessions:** Cached when viewing sessions screen
- **User Profile:** Cached when viewing profile

---

## 🎨 **User Experience**

### **Offline Indicator:**

When offline, users see a banner at the top:
```
🌐 Offline Mode - Showing cached data
```

### **Cache Timestamp:**

Users can see when data was last updated:
- "Last updated: 2 hours ago"
- "Showing cached data from yesterday"

### **Error Handling:**

- If no cache available: Shows "No data available offline"
- If cache expired: Shows "Data may be outdated"
- If action requires online: Shows "This action requires internet connection"

---

## 🌐 **Web Support**

Offline functionality works on web, but with limitations:

- **Cache Storage:** Uses browser's localStorage (SharedPreferences)
- **Connectivity Detection:** Works but may be less reliable
- **Cache Size:** Limited by browser storage limits (~5-10MB)
- **Best Practice:** Web users should refresh when back online

---

## 📊 **Cache Management**

### **Automatic:**
- Cache expires after 7 days
- Old cache is automatically cleared
- New data overwrites old cache

### **Manual:**
- Users can clear cache in settings
- Cache is cleared on logout
- Cache is cleared on app reinstall

---

## 🔧 **Technical Implementation**

### **Services:**
- `ConnectivityService`: Monitors network status
- `OfflineCacheService`: Manages local cache storage
- `OfflineIndicator`: UI component for offline banner

### **Data Services Updated:**
- `TutorService`: Checks cache when offline
- `BookingService`: Checks cache when offline
- `RecurringSessionService`: Checks cache when offline
- `IndividualSessionService`: Checks cache when offline

### **Cache Keys:**
- `cached_tutors`: Tutor discovery list
- `cached_tutor_details_{id}`: Individual tutor details
- `cached_booking_requests_{userId}`: User's booking requests
- `cached_recurring_sessions_{userId}`: User's recurring sessions
- `cached_individual_sessions_{userId}`: User's individual sessions
- `cached_user_profile_{userId}`: User's profile data

---

## 🚀 **Future Enhancements**

1. **Offline Action Queue**
   - Queue actions when offline
   - Sync when back online
   - Show pending actions indicator

2. **Smart Caching**
   - Pre-cache frequently accessed data
   - Cache based on user behavior
   - Predictive caching

3. **Offline-First Architecture**
   - Use local database (Hive/SQLite)
   - Real-time sync when online
   - Conflict resolution

---

**Last Updated:** January 2025





