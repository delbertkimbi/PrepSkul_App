# 📧 Email Architecture Explanation

**Why Email Templates Are in Next.js (Not Flutter)**

---

## 🎯 **Key Point: Emails Are NOT Received in the Flutter App**

### **Where Emails Are Actually Received:**
- ✅ **Email Clients:** Gmail, Outlook, Yahoo, Apple Mail, etc.
- ✅ **User's Email Inbox:** The email address they signed up with
- ❌ **NOT in the Flutter app** (emails are separate from the app)

---

## 🔄 **How Email Delivery Works**

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐         ┌──────────────┐
│   Flutter   │  ────>  │  Next.js API │  ────>  │   Resend    │  ────>  │ Email Client │
│    App      │         │   (Backend)  │         │  (Service)  │         │  (Gmail/etc) │
└─────────────┘         └──────────────┘         └─────────────┘         └──────────────┘
    Triggers              Generates HTML          Sends Email          User Receives
   notification           from template           via SMTP            in their inbox
```

### **Step-by-Step Flow:**

1. **Flutter App** triggers a notification (e.g., booking accepted)
2. **Next.js API** receives the request (`/api/notifications/send`)
3. **Next.js Backend** generates HTML email from template
4. **Resend Service** sends the email to user's email address
5. **User's Email Client** (Gmail, Outlook, etc.) receives and displays the email
6. **User** sees the email in their inbox (NOT in the Flutter app)

---

## 📧 **Why Email Templates Are Server-Side (Next.js)**

### **1. Email Templates Are HTML**
- Email clients render HTML, not Flutter widgets
- Templates generate HTML that email clients (Gmail, Outlook) can display
- This HTML needs to be generated on the server before sending

### **2. Email Sending Happens on Backend**
- Resend API (email service) is called from Next.js backend
- Flutter app doesn't directly send emails
- Backend needs the templates where email sending happens

### **3. Email Clients Render Templates**
- Gmail, Outlook, etc. render the HTML
- They don't understand Flutter widgets
- Templates must be HTML/CSS that email clients support

### **4. Separation of Concerns**
- **Flutter App:** Handles in-app notifications (UI)
- **Next.js Backend:** Handles email sending (server-side)
- **Email Clients:** Render and display emails

---

## 🎨 **What Goes Where**

### **Flutter App (Client-Side):**
- ✅ In-app notifications (bell icon, notification list)
- ✅ Push notifications (when implemented)
- ✅ Notification preferences UI
- ❌ **NOT email templates** (emails aren't rendered in app)

### **Next.js Backend (Server-Side):**
- ✅ Email templates (HTML generation)
- ✅ Email sending (Resend API)
- ✅ Scheduled notifications
- ✅ Notification processing

### **Email Clients (Gmail, Outlook, etc.):**
- ✅ Receive emails
- ✅ Render HTML templates
- ✅ Display emails to users

---

## 💡 **Alternative Architecture (Why It Doesn't Work)**

### **❌ Bad: Templates in Flutter**
```
Flutter App generates HTML → Sends to Next.js → Sends to Resend → Email Client
```
**Problems:**
- Flutter doesn't have email templates (it's for mobile apps)
- Templates need to be server-side for security
- Email sending should happen on backend, not client

### **✅ Good: Templates in Next.js (Current)**
```
Flutter triggers → Next.js generates HTML → Resend sends → Email Client
```
**Benefits:**
- Templates are server-side (secure)
- Backend handles email sending
- Email clients render HTML properly

---

## 📱 **Flutter App vs Email Clients**

### **In-App Notifications (Flutter):**
- User opens the Flutter app
- Sees notification bell with badge
- Taps to see notification list
- **This is separate from emails**

### **Email Notifications (Email Clients):**
- User receives email in Gmail/Outlook
- Email contains HTML content
- User clicks link to open Flutter app (deep linking)
- **This is separate from in-app notifications**

---

## 🔧 **How They Work Together**

### **Example: Booking Accepted**

1. **Tutor accepts booking in Flutter app**
2. **Flutter app calls Next.js API:**
   ```dart
   await http.post('/api/notifications/send', {
     userId: studentId,
     type: 'booking_accepted',
     title: 'Booking Accepted!',
     message: '...',
     sendEmail: true,
   });
   ```

3. **Next.js API generates email:**
   ```typescript
   // Next.js backend
   const emailBody = bookingAcceptedEmail(
     studentName,
     tutorName,
     subject,
     requestId,
   );
   
   await resend.emails.send({
     to: studentEmail,
     subject: 'Booking Accepted!',
     html: emailBody, // HTML template
   });
   ```

4. **Resend sends email to student's email address**

5. **Student receives email in Gmail/Outlook:**
   - Sees beautiful HTML email
   - Clicks "View Booking" button
   - Opens Flutter app (deep linking)

6. **Student also sees in-app notification:**
   - Opens Flutter app
   - Sees notification bell with badge
   - Taps to see notification list

---

## 📊 **Notification Channels**

### **1. In-App Notifications (Flutter):**
- **Where:** Flutter app
- **Templates:** Flutter widgets (NotificationItem, NotificationList)
- **Delivery:** Real-time via Supabase Realtime
- **User sees:** When they open the app

### **2. Email Notifications (Email Clients):**
- **Where:** Gmail, Outlook, etc.
- **Templates:** HTML (Next.js)
- **Delivery:** Resend API (SMTP)
- **User sees:** In their email inbox

### **3. Push Notifications (Future):**
- **Where:** System notification tray
- **Templates:** Notification payload (Next.js)
- **Delivery:** Firebase Cloud Messaging
- **User sees:** Even when app is closed

---

## ✅ **Summary**

### **Why Templates Are in Next.js:**
1. ✅ Emails are received in email clients (Gmail, Outlook), not Flutter app
2. ✅ Email templates are HTML that email clients render
3. ✅ Email sending happens on backend (Next.js), not client (Flutter)
4. ✅ Templates need to be server-side for security and performance

### **Flutter App's Role:**
- ✅ Triggers notifications (calls Next.js API)
- ✅ Displays in-app notifications (bell icon, list)
- ✅ Handles notification preferences
- ❌ Does NOT generate or send emails

### **Next.js Backend's Role:**
- ✅ Generates email HTML from templates
- ✅ Sends emails via Resend API
- ✅ Processes scheduled notifications
- ✅ Handles notification logic

---

## 🎯 **Conclusion**

**Email templates belong in Next.js because:**
- Emails are sent to email clients (Gmail, Outlook), not the Flutter app
- Templates are HTML that email clients render
- Email sending is a server-side operation
- This is the standard architecture for email notifications

**The Flutter app:**
- Triggers notifications
- Displays in-app notifications
- Does NOT handle email templates or sending

This architecture is correct and follows best practices! ✅

