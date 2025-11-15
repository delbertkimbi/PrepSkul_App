# 🚀 Pre-Launch Priority Plan

**Last Updated:** January 2025

---

## 📊 **CORE FEATURES NEEDED BEFORE LAUNCH**

Based on dependencies, UVP (Unique Value Proposition), importance, and need, here are the **critical features** that must be implemented before app launch:

---

## 🎯 **TOP PRIORITY TASK**

### **1. Payment Request Creation on Tutor Approval** 🔴 **CRITICAL**

**Why This is #1:**
- **UVP:** Core monetization feature - without payments, no revenue
- **Dependency:** Required for all other payment-related features
- **Importance:** Students can't pay, tutors can't earn without this
- **Need:** Must work before any real sessions can happen

**What It Does:**
- When tutor approves booking, automatically creates payment requests
- Calculates payment amounts based on plan (monthly/bi-weekly/weekly)
- Launches payment screen for student
- Enables the entire payment flow

**Dependencies:**
- Booking approval flow (✅ exists)
- Payment plan selection (✅ exists)
- Fapshi integration (✅ exists)

**Blocks:**
- All payment processing
- Tutor earnings
- Session lifecycle

---

## 📋 **EXECUTION ORDER (Priority-Based)**

### **PHASE 1: PAYMENT FOUNDATION** 🔴 **CRITICAL - WEEK 1**

#### **1.1 Payment Request Creation on Approval** ⏱️ 2-3 days
**Priority:** 🔴 **HIGHEST**
- Create payment requests when tutor approves
- Smart calculation (monthly/bi-weekly/weekly)
- Payment screen auto-launch
- Recurring payment scheduling

**Dependencies:** None (all prerequisites exist)
**Blocks:** Everything else in payment flow

#### **1.2 Complete Fapshi Webhook Integration** ⏱️ 1-2 days
**Priority:** 🔴 **CRITICAL**
- Payment confirmation webhook handler
- Payment status updates
- Balance movement (pending → active)
- Error handling

**Dependencies:** 1.1 (payment requests)
**Blocks:** Tutor earnings, wallet system

#### **1.3 Payment Status Tracking UI** ⏱️ 1 day
**Priority:** 🟡 **HIGH**
- Show payment status in student dashboard
- Payment history
- Retry failed payments

**Dependencies:** 1.1, 1.2
**Blocks:** User experience

---

### **PHASE 2: SESSION LIFECYCLE** 🟠 **HIGH PRIORITY - WEEK 2**

#### **2.1 Session Start/End Flow** ⏱️ 2-3 days
**Priority:** 🔴 **CRITICAL**
- Start session button (tutor)
- End session button (tutor)
- Status updates (scheduled → in_progress → completed)
- Meet link generation (when session starts)
- Attendance tracking initiation

**Dependencies:** None (sessions exist)
**Blocks:** All session features

#### **2.2 Meet Link Generation for Regular Sessions** ⏱️ 1-2 days
**Priority:** 🔴 **CRITICAL**
- Generate Meet link when session starts (not before)
- Google Calendar event creation
- Store link in database
- Send to both parties

**Dependencies:** 2.1 (session start)
**Blocks:** Online sessions can't happen

#### **2.3 Session Payment Processing** ⏱️ 2 days
**Priority:** 🔴 **CRITICAL**
- Create payment record when session ends
- Calculate tutor earnings (85%)
- Add to pending balance
- Link to payment requests (if recurring plan)

**Dependencies:** 2.1 (session end), 1.1 (payment requests)
**Blocks:** Tutor earnings, wallet

---

### **PHASE 3: QUALITY ASSURANCE & FEEDBACK** 🟡 **HIGH PRIORITY - WEEK 3**

#### **3.1 Session Feedback Collection UI** ⏱️ 2-3 days
**Priority:** 🔴 **CRITICAL**
- Student feedback form (24h after session)
- Rating (1-5 stars)
- Review text
- What went well / What could improve
- Would recommend (yes/no)

**Dependencies:** 2.1 (session completion)
**Blocks:** Quality assurance, pending → active balance movement

#### **3.2 Quality Assurance System** ⏱️ 2-3 days
**Priority:** 🔴 **CRITICAL**
- Feedback processing
- Issue detection (late coming, poor feedback, complaints)
- Fine calculation system
- Refund processing (worst case)
- Auto-move pending → active after 24-48h

**Dependencies:** 3.1 (feedback collection), 2.3 (payment processing)
**Blocks:** Tutor wallet active balance

#### **3.3 Points System Integration** ⏱️ 2 days
**Priority:** 🟡 **HIGH**
- Points calculation based on payment amount
- Points storage in user account
- Points display in UI
- Points usage for future sessions

**Dependencies:** 1.2 (payment confirmation)
**Blocks:** User engagement feature

---

### **PHASE 4: ATTENDANCE & TRACKING** 🟡 **MEDIUM-HIGH PRIORITY - WEEK 4**

#### **4.1 Attendance Tracking** ⏱️ 2 days
**Priority:** 🟡 **HIGH**
- Track who joined when
- Duration tracking
- Late arrival detection
- No-show detection
- Attendance history

**Dependencies:** 2.1 (session start/end)
**Blocks:** Quality assurance, fine calculation

#### **4.2 Onsite Session Location Display** ⏱️ 1-2 days
**Priority:** 🟡 **MEDIUM**
- Show address in session details
- Map integration (optional)
- Directions link
- Check-in functionality

**Dependencies:** 2.1 (session lifecycle)
**Blocks:** Onsite session UX

---

### **PHASE 5: ENHANCED FEATURES** 🟢 **MEDIUM PRIORITY - WEEK 5**

#### **5.1 Fathom AI Integration** ⏱️ 3-4 days
**Priority:** 🟡 **MEDIUM** (Nice-to-have for launch)
- Auto-join Google Meet
- Recording
- Transcription
- Summary generation
- Action items extraction

**Dependencies:** 2.2 (Meet links)
**Blocks:** Advanced session features (can launch without)

#### **5.2 Review Display on Tutor Profile** ⏱️ 1-2 days
**Priority:** 🟡 **MEDIUM**
- Show reviews on tutor profile
- Average rating calculation
- Review list
- Response functionality

**Dependencies:** 3.1 (feedback collection)
**Blocks:** Social proof (can launch without)

#### **5.3 Tutor Wallet Payout Requests** ⏱️ 2 days
**Priority:** 🟡 **MEDIUM**
- Payout request UI
- Withdrawal processing
- Payout history

**Dependencies:** 3.2 (active balance)
**Blocks:** Tutor earnings withdrawal (can launch without)

---

### **PHASE 6: POLISH & OPTIMIZATION** 🔵 **LOW PRIORITY - WEEK 6**

#### **6.1 Session Conflict Detection Improvements** ⏱️ 1 day
**Priority:** 🟢 **LOW**
- Better conflict detection
- Alternative suggestions
- Travel time checks

**Dependencies:** None
**Blocks:** UX improvement

#### **6.2 Session Rescheduling UI** ⏱️ 2 days
**Priority:** 🟢 **LOW**
- Request reschedule
- Approve/reject reschedule
- Update calendar

**Dependencies:** 2.1 (session lifecycle)
**Blocks:** Convenience feature (can launch without)

---

## 📊 **DEPENDENCY MAP**

```
Payment Request Creation (1.1)
    ↓
Fapshi Webhook (1.2) ──→ Payment Status UI (1.3)
    ↓
Session Start/End (2.1) ──→ Meet Links (2.2)
    ↓                          ↓
Session Payment (2.3) ──→ Feedback UI (3.1)
    ↓                          ↓
Quality Assurance (3.2) ──→ Points System (3.3)
    ↓
Attendance (4.1) ──→ Onsite Location (4.2)
    ↓
Fathom AI (5.1) ──→ Reviews Display (5.2) ──→ Payouts (5.3)
```

---

## 🎯 **MINIMUM VIABLE PRODUCT (MVP) FOR LAUNCH**

### **Must Have (Before Launch):**
1. ✅ Payment Request Creation on Approval
2. ✅ Fapshi Webhook Integration
3. ✅ Session Start/End Flow
4. ✅ Meet Link Generation
5. ✅ Session Payment Processing
6. ✅ Feedback Collection UI
7. ✅ Quality Assurance System (24-48h hold)
8. ✅ Pending → Active Balance Movement

### **Should Have (Can Launch Without, But Add Soon):**
1. ⏳ Attendance Tracking
2. ⏳ Onsite Location Display
3. ⏳ Points System
4. ⏳ Review Display

### **Nice to Have (Post-Launch):**
1. ⏳ Fathom AI Integration
2. ⏳ Tutor Payout Requests
3. ⏳ Session Rescheduling
4. ⏳ Conflict Detection Improvements

---

## ⏱️ **TIMELINE ESTIMATE**

### **Minimum Launch (MVP):**
- **Week 1:** Payment Foundation (1.1, 1.2, 1.3)
- **Week 2:** Session Lifecycle (2.1, 2.2, 2.3)
- **Week 3:** Quality Assurance (3.1, 3.2)
- **Total:** 3 weeks to MVP launch

### **Full Feature Launch:**
- **Week 1-3:** MVP (as above)
- **Week 4:** Attendance & Tracking (4.1, 4.2)
- **Week 5:** Enhanced Features (5.1, 5.2, 5.3)
- **Week 6:** Polish (6.1, 6.2)
- **Total:** 6 weeks to full launch

---

## 🔴 **CRITICAL PATH**

The **critical path** to launch (features that block everything):

1. **Payment Request Creation** → Blocks all payments
2. **Session Start/End** → Blocks all sessions
3. **Feedback Collection** → Blocks quality assurance
4. **Quality Assurance** → Blocks pending → active balance

**If any of these fail, launch is blocked.**

---

## 📝 **NOTES**

- **Pending Balance:** 24-48 hours for quality assurance (feedback, fines, refunds)
- **Active Balance:** Auto-moves after quality period passes
- **Points System:** Payments give points based on tutor pricing
- **Refunds:** Can go to PrepSkul account (points) or back to Momo
- **Fines:** Deducted from pending balance before moving to active

---

## ✅ **SUCCESS CRITERIA**

Launch is ready when:
- ✅ Students can book tutors
- ✅ Tutors can approve/reject
- ✅ Payment requests are created
- ✅ Students can pay
- ✅ Sessions can start/end
- ✅ Feedback can be collected
- ✅ Earnings move to active balance
- ✅ Quality assurance works

---

**Last Updated:** January 2025





