# 📚 Admin Dashboard - User Guide

## 🚀 Quick Start

**Login URL:** `http://localhost:3000/admin/login`  
**Credentials:** Your admin email & password

---

## 📊 **Dashboard Overview** (`/admin`)

### What You See:
```
┌─────────────────────────────────────────────────────────┐
│  PrepSkul Admin                    [Dashboard] [Tutors] │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  Dashboard                                                │
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐│
│  │ Total    │  │ Pending  │  │ Active   │  │ Revenue  ││
│  │ Users    │  │ Tutors   │  │ Sessions │  │ (XAF)    ││
│  │   127    │  │    5     │  │    23    │  │  450,000 ││
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘│
│                                                           │
└─────────────────────────────────────────────────────────┘
```

**Live Metrics:**
- Numbers update automatically when you refresh
- Click "Pending Tutors" badge to go to review page

---

## 👥 **Pending Tutors** (`/admin/tutors/pending`)

### Main List View:
```
┌─────────────────────────────────────────────────────────┐
│  Pending Tutor Applications          [5 Pending]         │
├─────────────────────────────────────────────────────────┤
│  [Search...] [Filter: All Subjects] [Filter: Location]  │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐│
│  │  👤 John Kamga                                       ││
│  │  Mathematics, Physics                                ││
│  │  Douala • 3 years experience                         ││
│  │  Applied: Jan 15, 2025                               ││
│  │  Phone: +237671234567                                ││
│  │                                                       ││
│  │  [Approve] [Reject] [View Details]                   ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

**Actions:**
- **Quick Approve** - Approves immediately (no notes)
- **View Details** - Opens full profile for detailed review

---

## 📋 **Tutor Detail Page** (`/admin/tutors/[id]`)

### Full Profile Layout:

```
┌─────────────────────────────────────────────────────────┐
│  ← Back to Pending Tutors                                │
│                                                           │
│  John Kamga                              [Pending]        │
├─────────────────────────────────────────────────────────┤
│  Quick Actions                                            │
│  [📱 Call] [📧 Email] [💬 WhatsApp]                       │
├─────────────────────────────────────────────────────────┤
│  Personal Information                                     │
│  Full Name: John Kamga                                    │
│  Email: john.kamga@email.com                              │
│  Phone: +237671234567                                     │
│  City: Douala                                             │
│  Quarter: Bonamoussadi                                    │
│  Years of Experience: 3 years                             │
├─────────────────────────────────────────────────────────┤
│  Academic Background                                      │
│  Education Level: Bachelor's Degree                       │
│  Current Level: Year 3                                    │
│  Field of Study: Mathematics                              │
│  Institution: University of Douala                        │
├─────────────────────────────────────────────────────────┤
│  Tutoring Details                                         │
│  Tutoring Areas:                                          │
│  [Mathematics] [Physics] [Chemistry]                      │
│                                                           │
│  Learner Levels:                                          │
│  [Form 1-5] [Lower Sixth] [Upper Sixth]                  │
│                                                           │
│  About / Motivation:                                      │
│  "I am passionate about helping students..."              │
├─────────────────────────────────────────────────────────┤
│  Documents                                                │
│  Profile Photo:     Certificates:                         │
│  [Photo displayed]  [↓ Certificate 1]                     │
│                     [↓ Certificate 2]                     │
│                                                           │
│  ID Card (Front):   ID Card (Back):                       │
│  [View ID Front]    [View ID Back]                        │
│                                                           │
│  Video Introduction:                                      │
│  [🔗 Watch Video]                                         │
├─────────────────────────────────────────────────────────┤
│  Admin Notes                                              │
│  ┌───────────────────────────────────────────────────┐  │
│  │ Called on Jan 16. Verified credentials.           │  │
│  │ ID photo unclear - requested new upload.          │  │
│  └───────────────────────────────────────────────────┘  │
│  [Save Notes]                                             │
├─────────────────────────────────────────────────────────┤
│  Review Actions                                           │
│  ┌─────────────────────┐  ┌─────────────────────┐       │
│  │ Approval Notes:      │  │ Rejection Reason:   │       │
│  │ [Optional text...]   │  │ [Required text...]  │       │
│  │ [✓ Approve Tutor]    │  │ [✗ Reject]          │       │
│  └─────────────────────┘  └─────────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

---

## 🔄 **Complete Review Workflow**

### **Scenario 1: Everything Looks Good**

1. **Go to Pending Tutors** (`/admin/tutors/pending`)
2. **Click "View Details"** on a tutor
3. **Review all sections:**
   - ✅ Personal info correct
   - ✅ Academic background verified
   - ✅ Documents uploaded and clear
   - ✅ Video introduction watched
4. **Scroll to "Review Actions"**
5. **Type approval notes** (optional):
   ```
   "Excellent profile. All documents verified. 
   Teaching experience confirmed via phone call."
   ```
6. **Click "✓ Approve Tutor"**
7. **Tutor is now approved** and removed from pending list

---

### **Scenario 2: Need to Contact Tutor**

1. **View tutor's full profile**
2. **Click on one of the contact buttons:**
   
   **📱 Call:**
   - Automatically dials their phone number
   - Discuss credentials or ask for clarifications
   
   **📧 Email:**
   - Opens your email client
   - Tutor's email pre-filled in "To" field
   - Write message about corrections needed
   
   **💬 WhatsApp:**
   - Opens WhatsApp chat with tutor
   - Quick messaging for simple questions

3. **After conversation, add notes:**
   ```
   "Called on Jan 16, 2025 at 2:30 PM.
   Tutor confirmed availability for weekends.
   Requested to upload clearer ID photo.
   Follow up in 2 days."
   ```
4. **Click "Save Notes"**
5. **Wait for tutor to make corrections**
6. **Come back later to re-review**

---

### **Scenario 3: Must Reject**

1. **View tutor's profile**
2. **Identify issue:**
   - Insufficient experience
   - Invalid documents
   - Mismatch in qualifications
3. **Scroll to "Review Actions"**
4. **Type rejection reason** (REQUIRED):
   ```
   "ID card photo is not clear enough to verify identity.
   Please re-submit a high-quality scan of both sides.
   
   Also, certificates do not match the subjects listed
   in your tutoring areas."
   ```
5. **Click "✗ Reject Application"**
6. **Tutor receives notification** with your notes
7. **They can re-apply after corrections**

---

## 💡 **Pro Tips**

### **Using Admin Notes Effectively:**

✅ **Good Notes:**
```
"Jan 16, 2025 - Phone call:
- Verified teaching experience at St. Joseph's College
- Confirmed availability: Mon-Fri 4pm-8pm
- Requested updated teaching certificate (expires soon)
- Follow up: Jan 20"

"Jan 20, 2025 - Re-review:
- New certificate uploaded ✓
- All documents verified ✓
- Approved and notified tutor"
```

❌ **Poor Notes:**
```
"Looks good"
"Called"
"OK"
```

### **Best Practices:**

1. **Always add dates** to your notes
2. **Document phone calls** and what was discussed
3. **Track follow-ups** - when to check back
4. **Be specific** in approval/rejection notes
5. **Use notes for training** - other admins can learn from your reviews

---

## 🎯 **Common Tasks**

### **How to check total pending tutors:**
→ Look at Dashboard metric "Pending Tutors"

### **How to find a specific tutor:**
→ Go to Pending Tutors → Use search bar → Type name

### **How to download a tutor's certificate:**
→ View Details → Documents section → Click "Certificate 1/2/3"

### **How to see who approved a tutor:**
→ Database stores `reviewed_by` (admin user ID) and `reviewed_at` (timestamp)

### **How to change a decision:**
→ Currently: Manual database update  
→ Future: Add "Reverse Decision" button

---

## 🔐 **Security Reminders**

- ✅ **Never share admin login** with non-admin users
- ✅ **Always log out** when done (`/admin/logout` - coming soon)
- ✅ **Verify documents carefully** before approval
- ✅ **Keep notes professional** - tutors may see rejection reasons

---

## 📞 **Need Help?**

- **Technical Issues:** Contact dev team
- **Policy Questions:** Check tutor approval guidelines
- **Urgent:** Call admin hotline

---

## ✅ **Quick Reference**

| Action | Where | Button/Link |
|--------|-------|-------------|
| View metrics | `/admin` | Dashboard tab |
| See pending list | `/admin/tutors/pending` | Tutors tab |
| Review full profile | Click "View Details" | On any tutor card |
| Call tutor | Detail page | 📱 Call button |
| Email tutor | Detail page | 📧 Email button |
| WhatsApp tutor | Detail page | 💬 WhatsApp button |
| Save notes | Detail page | "Save Notes" button |
| Approve | Detail page | ✓ Approve Tutor |
| Reject | Detail page | ✗ Reject Application |

---

**Dashboard is ready to use! Start reviewing tutors now.** 🚀

