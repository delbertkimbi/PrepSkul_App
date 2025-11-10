# 🔔 PrepSkul Notification System - Complete Plan & Implementation

**Status:** Planning Phase  
**Created:** January 2025  
**Goal:** Idiot-proof, seamless, beautiful in-app and email notifications

---

## 📋 **Table of Contents**

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Notification Types](#notification-types)
4. [Database Schema](#database-schema)
5. [Implementation Plan](#implementation-plan)
6. [User Experience](#user-experience)
7. [Technical Details](#technical-details)

---

## 🎯 **Overview**

### **What We're Building**

A comprehensive, user-friendly notification system that:
- ✅ Sends **in-app notifications** (real-time, beautiful UI)
- ✅ Sends **email notifications** (using Resend)
- ✅ Supports **scheduled notifications** (session reminders, payment due)
- ✅ Allows **user preferences** (customize what they receive)
- ✅ Works **seamlessly** across web, Android, and iOS
- ✅ **Idiot-proof** (clear, simple, actionable)

### **Key Features**

1. **Real-time In-App Notifications**
   - Bell icon with unread badge
   - Notification list with filtering
   - Mark as read/unread
   - Deep linking to related content

2. **Email Notifications**
   - Beautiful HTML templates
   - Personalized content
   - Actionable CTAs
   - Mobile-responsive

3. **Scheduled Notifications**
   - Session reminders (30 min before)
   - Payment due reminders
   - Review reminders (after session)
   - Follow-up notifications

4. **User Preferences**
   - Enable/disable notification types
   - Choose email vs in-app
   - Quiet hours (no notifications)
   - Digest mode (daily/weekly summary)

---

## 🏗️ **Architecture**

### **System Components**

```
┌─────────────────────────────────────────────────────────────┐
│                    NOTIFICATION SYSTEM                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────┐  │
│  │   Events     │ ───> │ Notification │ ───> │  Users   │  │
│  │  (Triggers)  │      │   Service    │      │  (In-App │  │
│  └──────────────┘      └──────────────┘      │  + Email)│  │
│        │                       │               └──────────┘  │
│        │                       │                             │
│        │              ┌────────┴────────┐                   │
│        │              │                 │                   │
│        │         ┌────▼────┐      ┌────▼────┐              │
│        │         │  In-App │      │  Email  │              │
│        │         │    DB   │      │ Resend  │              │
│        │         └─────────┘      └─────────┘              │
│        │                                                     │
│  ┌─────▼─────────┐                                          │
│  │   Scheduled   │                                          │
│  │  (Background) │                                          │
│  └───────────────┘                                          │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### **Data Flow**

1. **Event Occurs** (e.g., booking request, payment, session start)
2. **Notification Service** checks user preferences
3. **Creates In-App Notification** (database)
4. **Sends Email** (if enabled, via Resend)
5. **Schedules Reminders** (if needed, background job)
6. **Real-time Update** (Supabase Realtime → Flutter app)

---

## 📬 **Notification Types**

### **1. Tutor Notifications**

| Type | Trigger | In-App | Email | Schedule |
|------|---------|--------|-------|----------|
| **Profile Approved** | Admin approves profile | ✅ | ✅ | - |
| **Profile Rejected** | Admin rejects profile | ✅ | ✅ | - |
| **Needs Improvement** | Admin requests changes | ✅ | ✅ | - |
| **Booking Request** | Student requests session | ✅ | ✅ | - |
| **Request Approved** | Student accepts booking | ✅ | ✅ | - |
| **Request Rejected** | Student rejects booking | ✅ | ✅ | - |
| **Payment Received** | Payment completed | ✅ | ✅ | - |
| **Session Starting Soon** | 30 min before session | ✅ | ✅ | ✅ 30 min |
| **Session Reminder** | 24 hours before | ✅ | ✅ | ✅ 24 hours |
| **Review Received** | Student leaves review | ✅ | ✅ | - |
| **Unblock Request Response** | Admin responds | ✅ | ✅ | - |

### **2. Student/Parent Notifications**

| Type | Trigger | In-App | Email | Schedule |
|------|---------|--------|-------|----------|
| **Booking Accepted** | Tutor accepts request | ✅ | ✅ | - |
| **Booking Rejected** | Tutor rejects request | ✅ | ✅ | - |
| **Payment Successful** | Payment processed | ✅ | ✅ | - |
| **Payment Failed** | Payment fails | ✅ | ✅ | - |
| **Session Starting Soon** | 30 min before | ✅ | ✅ | ✅ 30 min |
| **Session Reminder** | 24 hours before | ✅ | ✅ | ✅ 24 hours |
| **Session Completed** | Session ends | ✅ | ✅ | - |
| **Review Reminder** | After session | ✅ | ✅ | ✅ 24 hours |
| **Tutor Message** | Tutor sends message | ✅ | ✅ | - |

### **3. Admin Notifications**

| Type | Trigger | In-App | Email | Schedule |
|------|---------|--------|-------|----------|
| **New Tutor Application** | Tutor submits profile | ✅ | ✅ | - |
| **New Booking Request** | Student requests tutor | ✅ | ✅ | - |
| **Payment Issue** | Payment fails/refunds | ✅ | ✅ | - |
| **Session Flag** | Fathom flags session | ✅ | ✅ | - |
| **Unblock Request** | Tutor requests unblock | ✅ | ✅ | - |

---

## 🗄️ **Database Schema**

### **1. Enhanced Notifications Table**

```sql
-- Enhanced notifications table (already exists, need to enhance)
ALTER TABLE public.notifications 
  ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'general',
  ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  ADD COLUMN IF NOT EXISTS action_url TEXT, -- Deep link to related content
  ADD COLUMN IF NOT EXISTS action_text TEXT, -- "View Booking", "Accept Request", etc.
  ADD COLUMN IF NOT EXISTS icon TEXT, -- Emoji or icon name
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ, -- Auto-delete after expiry
  ADD COLUMN IF NOT EXISTS metadata JSONB; -- Additional data (session_id, booking_id, etc.)
```

### **2. Notification Preferences Table**

```sql
-- User notification preferences
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
  
  -- Notification channels
  email_enabled BOOLEAN DEFAULT TRUE,
  in_app_enabled BOOLEAN DEFAULT TRUE,
  push_enabled BOOLEAN DEFAULT TRUE, -- For future push notifications
  
  -- Type-specific preferences (JSONB for flexibility)
  type_preferences JSONB DEFAULT '{
    "profile_approved": {"email": true, "in_app": true},
    "booking_request": {"email": true, "in_app": true},
    "payment_received": {"email": true, "in_app": true},
    "session_reminder": {"email": true, "in_app": true},
    "review_received": {"email": false, "in_app": true}
  }'::jsonb,
  
  -- Quiet hours (no notifications during this time)
  quiet_hours_start TIME, -- e.g., "22:00"
  quiet_hours_end TIME,   -- e.g., "08:00"
  
  -- Digest mode
  digest_enabled BOOLEAN DEFAULT FALSE,
  digest_frequency TEXT DEFAULT 'daily' CHECK (digest_frequency IN ('daily', 'weekly', 'never')),
  digest_time TIME DEFAULT '09:00',
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_notification_preferences_user 
  ON public.notification_preferences(user_id);

-- RLS Policies
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own preferences"
  ON public.notification_preferences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences"
  ON public.notification_preferences FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences"
  ON public.notification_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

### **3. Scheduled Notifications Table**

```sql
-- Scheduled notifications (for reminders, etc.)
CREATE TABLE IF NOT EXISTS public.scheduled_notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  notification_type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  scheduled_for TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'cancelled', 'failed')),
  related_id UUID, -- session_id, booking_id, etc.
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  sent_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_user 
  ON public.scheduled_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_status 
  ON public.scheduled_notifications(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_scheduled 
  ON public.scheduled_notifications(scheduled_for) 
  WHERE status = 'pending';

-- RLS Policies
ALTER TABLE public.scheduled_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own scheduled notifications"
  ON public.scheduled_notifications FOR SELECT
  USING (auth.uid() = user_id);
```

---

## 🔨 **Implementation Plan**

### **Phase 1: Database & Core Service** (Day 1)

#### **Tasks:**
1. ✅ Create migration for notification preferences
2. ✅ Create migration for scheduled notifications
3. ✅ Enhance notifications table schema
4. ✅ Update NotificationService in Flutter
5. ✅ Create NotificationService in Next.js (API routes)

#### **Files to Create/Update:**
- `supabase/migrations/019_notification_system.sql`
- `lib/core/services/notification_service.dart` (enhance)
- `PrepSkul_Web/app/api/notifications/` (new API routes)

### **Phase 2: In-App UI** (Day 2)

#### **Tasks:**
1. ✅ Create notification bell widget (with badge)
2. ✅ Create notification list screen
3. ✅ Create notification detail screen
4. ✅ Add notification preferences screen
5. ✅ Integrate real-time updates (Supabase Realtime)

#### **Files to Create:**
- `lib/features/notifications/screens/notification_list_screen.dart`
- `lib/features/notifications/screens/notification_detail_screen.dart`
- `lib/features/notifications/screens/notification_preferences_screen.dart`
- `lib/features/notifications/widgets/notification_bell.dart`
- `lib/features/notifications/widgets/notification_item.dart`

### **Phase 3: Email Templates** (Day 3)

#### **Tasks:**
1. ✅ Create email template system
2. ✅ Create templates for all notification types
3. ✅ Integrate with Resend
4. ✅ Add email preferences logic

#### **Files to Create/Update:**
- `PrepSkul_Web/lib/email_templates/` (new directory)
- `PrepSkul_Web/lib/email_templates/booking_request.ts`
- `PrepSkul_Web/lib/email_templates/session_reminder.ts`
- `PrepSkul_Web/lib/email_templates/payment_received.ts`
- `PrepSkul_Web/lib/notifications.ts` (enhance)

### **Phase 4: Event Integration** (Day 4)

#### **Tasks:**
1. ✅ Integrate with booking requests
2. ✅ Integrate with tutor approval/rejection
3. ✅ Integrate with payment system
4. ✅ Integrate with session system
5. ✅ Integrate with review system

#### **Files to Update:**
- `lib/features/booking/services/trial_session_service.dart`
- `lib/features/booking/services/booking_service.dart`
- `PrepSkul_Web/app/api/admin/tutors/[id]/approve/send/route.ts`
- `PrepSkul_Web/app/api/admin/tutors/[id]/reject/send/route.ts`

### **Phase 5: Scheduled Notifications** (Day 5)

#### **Tasks:**
1. ✅ Create background job system (Next.js API route)
2. ✅ Schedule session reminders
3. ✅ Schedule payment reminders
4. ✅ Schedule review reminders
5. ✅ Create cron job or scheduled function

#### **Files to Create:**
- `PrepSkul_Web/app/api/cron/process-scheduled-notifications/route.ts`
- `PrepSkul_Web/lib/services/scheduler_service.ts`

### **Phase 6: Testing & Polish** (Day 6)

#### **Tasks:**
1. ✅ Test all notification types
2. ✅ Test email delivery
3. ✅ Test real-time updates
4. ✅ Test scheduled notifications
5. ✅ Test user preferences
6. ✅ UI/UX polish
7. ✅ Performance optimization

---

## 🎨 **User Experience**

### **In-App Notifications**

#### **Bell Icon (Always Visible)**
- Located in app bar/navigation
- Shows unread count badge
- Tappable to open notification list
- Badge disappears when all read

#### **Notification List**
- Grouped by date (Today, Yesterday, This Week, Older)
- Filter by type (All, Booking, Payment, Session, etc.)
- Swipe to mark as read/delete
- Pull to refresh
- Empty state with helpful message

#### **Notification Item**
- Icon (emoji or image)
- Title (bold)
- Message (truncated with "Read more")
- Timestamp (relative: "2 hours ago")
- Action button (if applicable: "View Booking", "Accept", etc.)
- Visual indicator for unread (blue dot)

#### **Notification Detail**
- Full message
- Related content preview (booking details, session info)
- Action buttons
- Mark as read/unread
- Delete

### **Email Notifications**

#### **Design Principles**
- Clean, modern, mobile-responsive
- PrepSkul branding (colors, logo)
- Clear hierarchy (title → message → CTA)
- Personalization (use name, context)
- Actionable (clear next steps)

#### **Template Structure**
```
┌─────────────────────────────────────┐
│  Header (Logo, Brand Colors)        │
├─────────────────────────────────────┤
│  Icon/Emoji (Large, Centered)       │
│  Title (Bold, Clear)                │
│  Greeting (Hi [Name],)              │
├─────────────────────────────────────┤
│  Message Body (Friendly, Clear)     │
│  Details (If applicable)            │
│  Action Button (Primary CTA)        │
├─────────────────────────────────────┤
│  Footer (Unsubscribe, Support)      │
└─────────────────────────────────────┘
```

---

## 🛠️ **Technical Details**

### **Notification Service Architecture**

#### **Flutter (Client)**
```dart
class NotificationService {
  // Create notification
  static Future<void> createNotification({...})
  
  // Get notifications
  static Future<List<Notification>> getNotifications({...})
  
  // Mark as read
  static Future<void> markAsRead(String id)
  
  // Get preferences
  static Future<NotificationPreferences> getPreferences()
  
  // Update preferences
  static Future<void> updatePreferences({...})
  
  // Real-time subscription
  static Stream<List<Notification>> watchNotifications()
}
```

#### **Next.js (Server)**
```typescript
// API Route: /api/notifications/send
export async function POST(request: Request) {
  // 1. Check user preferences
  // 2. Create in-app notification
  // 3. Send email (if enabled)
  // 4. Schedule reminders (if needed)
}

// API Route: /api/notifications/schedule
export async function POST(request: Request) {
  // Schedule a notification for future
}

// Cron Job: /api/cron/process-scheduled-notifications
export async function GET(request: Request) {
  // Process all pending scheduled notifications
}
```

### **Real-time Updates**

Use Supabase Realtime to subscribe to notifications:

```dart
// In Flutter
final subscription = supabase
  .from('notifications')
  .stream(primaryKey: ['id'])
  .eq('user_id', userId)
  .order('created_at', ascending: false)
  .listen((data) {
    // Update UI with new notifications
  });
```

### **Scheduled Notifications**

Use Vercel Cron Jobs or a scheduled function:

```typescript
// Vercel Cron Job (vercel.json)
{
  "crons": [{
    "path": "/api/cron/process-scheduled-notifications",
    "schedule": "*/5 * * * *" // Every 5 minutes
  }]
}
```

---

## ✅ **Success Criteria**

### **Functional Requirements**
- ✅ All notification types work (in-app + email)
- ✅ User preferences work correctly
- ✅ Scheduled notifications are sent on time
- ✅ Real-time updates work seamlessly
- ✅ Email delivery is reliable (Resend)
- ✅ Notifications are actionable (deep links work)

### **Non-Functional Requirements**
- ✅ Performance: Notifications load in < 1 second
- ✅ Reliability: 99.9% notification delivery
- ✅ User Experience: Intuitive, beautiful UI
- ✅ Scalability: Handle 10,000+ notifications/day
- ✅ Security: RLS policies enforced

---

## 📝 **Next Steps**

1. **Review this plan** with the team
2. **Create database migrations** (Phase 1)
3. **Implement core service** (Phase 1)
4. **Build UI components** (Phase 2)
5. **Create email templates** (Phase 3)
6. **Integrate with events** (Phase 4)
7. **Add scheduling** (Phase 5)
8. **Test & polish** (Phase 6)

---

## 🎯 **Summary**

This notification system will provide a seamless, user-friendly experience for all PrepSkul users. It's designed to be:
- **Idiot-proof**: Clear, simple, actionable
- **Beautiful**: Modern UI, responsive emails
- **Seamless**: Real-time updates, no friction
- **Comprehensive**: All events covered
- **Flexible**: User preferences, scheduling

**Let's build it! 🚀**

