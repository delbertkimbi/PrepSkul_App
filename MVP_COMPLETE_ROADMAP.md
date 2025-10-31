# 🚀 MVP Complete Roadmap - Step by Step

## ✅ **Completed:**
1. ✅ Admin dashboard mobile menu
2. ✅ Admin authentication & pages
3. ✅ Flutter app basic flows
4. ✅ Database schema

---

## 📋 **MVP Features - In Order**

### **STEP 1: Email Auth + Tutor Onboarding** 🎯 **CURRENT**
- [ ] Add email/password auth for tutors (optional alongside phone)
- [ ] Create tutor onboarding flow (multi-step form)
- [ ] Save tutor data to `tutor_profiles`
- [ ] Real-time dashboard tracking
- [ ] Test: Signup → Dashboard shows pending

**Estimated:** 2-3 hours

---

### **STEP 2: Admin Review System**
- [ ] Enhance pending tutors page
- [ ] Approve/Reject buttons with message input
- [ ] Email notification to tutor (approved/rejected)
- [ ] Status updates in real-time
- [ ] Test: Approve → Tutor receives email → Status updates

**Estimated:** 1-2 hours

---

### **STEP 3: Tutor Discovery & Connection**
- [ ] Show only approved tutors in Find Tutors
- [ ] Booking flow connects student/parent with tutor
- [ ] Real-time availability sync
- [ ] Test: Book approved tutor → Request sent

**Estimated:** 2 hours

---

### **STEP 4: Trial Session System**
- [ ] Trial session booking enhanced
- [ ] In-app video calling integration
- [ ] Session start/end tracking
- [ ] Real-time monitoring in admin dashboard
- [ ] Test: Book trial → Join call → Admin sees live session

**Estimated:** 3-4 hours

---

### **STEP 5: Payment Integration**
- [ ] In-app payment processing (Fapshi API)
- [ ] Payment verification
- [ ] Session unlock after payment
- [ ] Revenue tracking in admin
- [ ] Test: Make payment → Session unlocked → Admin sees revenue

**Estimated:** 4-5 hours

---

### **STEP 6: Feedback System**
- [ ] Post-session rating & review
- [ ] Tutor/Student feedback forms
- [ ] Display ratings on profiles
- [ ] Admin dashboard analytics
- [ ] Test: Complete session → Rate → Review appears

**Estimated:** 2-3 hours

---

### **STEP 7: Notifications & Polish**
- [ ] Email notifications (session reminders, approvals)
- [ ] SMS notifications (optional)
- [ ] Push notifications (future)
- [ ] UI/UX polish
- [ ] Bug fixes
- [ ] Test: End-to-end user journey

**Estimated:** 3-4 hours

---

## 🎯 **Total Estimated Time: 17-23 hours**

---

## 📦 **Deployment Strategy**

### **During Development:**
- ✅ Admin dashboard: Auto-deploy on push to main (Vercel)
- ⏳ Flutter app: Deploy to Firebase after each major feature
- ✅ Database: Use same Supabase project (both apps)

### **Deployment Commands:**
```bash
# Flutter Web Deployment
cd prepskul_app
flutter build web --release
firebase deploy --only hosting

# Admin Dashboard (auto on push)
git push origin main
# Vercel auto-deploys
```

---

## 🧪 **Testing Plan**

After each step:
1. Test feature in Flutter app
2. Verify data in admin dashboard
3. Test real-time updates
4. Deploy to Firebase for mobile/web testing
5. Fix any issues before next step

---

## 📝 **Step 1 Details: Email Auth + Tutor Onboarding**

### **A. Email Authentication**
- Add email/password option to tutor signup
- Validate email format
- Password requirements
- Email verification (optional for MVP)

### **B. Tutor Onboarding Flow**
Multi-step form:
1. Personal Info (name, email, phone)
2. Education & Experience
3. Subjects & Specialization
4. Teaching Mode (online/in-person/hybrid)
5. Availability Schedule
5. Pricing & Rates
6. Profile Picture & Bio
7. Review & Submit

### **C. Database Integration**
- Save to `tutor_profiles` with status 'pending'
- Link to `profiles` table
- Auto-create profile entry

### **D. Real-time Dashboard**
- Pending tutors count updates
- New tutor appears immediately
- Admin can review right away

---

## 🚀 **Let's Start Step 1!**

Ready to build email auth + tutor onboarding flow!

