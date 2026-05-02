# Transportation Cost System Design

**Status:** 🟡 Design Phase - Not Implemented  
**Last Updated:** January 2025

---

## 🎯 **Core Principles**

1. **Platform fee (15%) applies ONLY to session fee, NOT transportation**
2. **Tutor's base pay remains consistent** (85% of session fee) regardless of location
3. **Transportation is parent compensation** for tutor's travel, not part of tutor's base earnings
4. **Fair cost sharing** between tutor and parent
5. **Flexible withdrawal** for tutors (weekly or monthly)

---

## 💰 **Cost Structure**

### **Base Session Fee (Online & Onsite)**
- **Same for both:** Tutor's normal per-session rate
- **Platform fee:** 15% of session fee
- **Tutor earnings:** 85% of session fee

### **Transportation Cost (Onsite Only)**
- **Range:** 200 XAF - 1,000 XAF (round trip)
- **Calculation:** Based on OSRM routing distance (tutor home → onsite address)
- **Platform fee:** ❌ **ZERO** (not charged on transportation)
- **Purpose:** Parent compensation for tutor transportation

---

## 🤔 **Cost Sharing Options**

### **Option A: 50/50 Split (Current Proposal)**
```
Transportation Cost: 600 XAF
├── Parent pays: 300 XAF (50%)
└── Tutor contributes: 300 XAF (50% from their 85% earnings)
    └── Tutor net: 85% session fee - 300 XAF
```

**Pros:**
- Shared burden
- Tutor still gets fair compensation

**Cons:**
- Reduces tutor's effective earnings
- May discourage onsite sessions
- Complex calculation

---

### **Option B: Parent Pays Full (Recommended)**
```
Transportation Cost: 600 XAF
├── Parent pays: 600 XAF (100%)
└── Tutor receives: 600 XAF (100% as separate transportation earnings)
    └── Tutor net: 85% session fee + 600 XAF transportation
```

**Pros:**
- ✅ **Simpler calculation**
- ✅ **Tutor gets full compensation** (session fee + transportation)
- ✅ **Encourages onsite sessions** (tutors benefit)
- ✅ **Clear separation** (session fee vs transportation)
- ✅ **Parent knows exact cost upfront**

**Cons:**
- Higher cost for parents (but transparent)

---

### **Option C: Platform Subsidizes (Alternative)**
```
Transportation Cost: 600 XAF
├── Parent pays: 400 XAF (67%)
├── Platform subsidizes: 100 XAF (17%)
└── Tutor contributes: 100 XAF (17% from earnings)
```

**Pros:**
- Reduces parent burden
- Platform can absorb small cost

**Cons:**
- Platform loses revenue
- More complex

---

## ✅ **RECOMMENDED: Option B (Parent Pays Full)**

### **Rationale:**
1. **Transparency:** Parent sees exact cost upfront
2. **Fairness:** Tutor gets compensated for travel time/cost
3. **Simplicity:** No complex splits or deductions
4. **Incentive:** Tutors prefer onsite (get transportation bonus)
5. **Platform neutrality:** Platform doesn't profit from transportation

### **Implementation:**
```
Total Parent Payment = Session Fee + Transportation Cost

Session Fee Breakdown:
├── Platform fee: 15% of session fee
└── Tutor earnings: 85% of session fee

Transportation Cost Breakdown:
├── Platform fee: 0% (FREE)
└── Tutor transportation earnings: 100% of transportation cost
```

---

## 📊 **Balance System**

### **Current System:**
- **Pending Balance:** Earnings awaiting 24h quality assurance
- **Active Balance:** Available for withdrawal after 24h

### **Transportation Balance Structure:**

#### **Option 1: Separate Transportation Balance**
```
Tutor Wallet:
├── Session Earnings (Pending/Active)
│   └── 85% of session fee
└── Transportation Earnings (Pending/Active)
    └── 100% of transportation cost
```

**Pros:**
- Clear separation
- Easy to track
- Can withdraw separately

**Cons:**
- More complex UI
- Two balances to manage

---

#### **Option 2: Combined Balance (Recommended)**
```
Tutor Wallet:
├── Pending Balance
│   ├── Session earnings (85% session fee)
│   └── Transportation earnings (100% transport cost)
└── Active Balance
    ├── Session earnings (85% session fee)
    └── Transportation earnings (100% transport cost)
```

**Pros:**
- ✅ **Simpler UI** (one balance)
- ✅ **Same 24h quality assurance** for both
- ✅ **Can withdraw together or separately** (filter by type)

**Cons:**
- Need to track source (session vs transport) in records

---

## 💸 **Withdrawal System**

### **Current System:**
- Tutors can withdraw from active balance
- Minimum: 5,000 XAF
- Withdrawal requests go to admin for approval

### **Transportation Withdrawal Options:**

#### **Option A: Weekly On-Demand (Current Proposal)**
```
Tutor can request transportation withdrawal:
- For onsite sessions only
- Weekly basis (last 7 days)
- Based on current learner(s) location
- Not entire transportation balance
```

**Example:**
- Tutor has 5 onsite sessions this week
- Total transportation: 3,000 XAF
- Can withdraw: 3,000 XAF (this week's transport)
- Cannot withdraw: Previous weeks' transportation (unless monthly)

---

#### **Option B: Flexible Withdrawal (Recommended)**
```
Tutor can withdraw:
- Any amount from active balance (including transportation)
- Minimum: 5,000 XAF (combined)
- Weekly or monthly (tutor choice)
- Filter by type (session earnings vs transportation) - optional
```

**Pros:**
- ✅ **More flexible**
- ✅ **Simpler implementation**
- ✅ **Tutor controls when to withdraw**
- ✅ **Same minimum threshold**

---

#### **Option C: Automatic Monthly**
```
Transportation automatically withdrawn:
- At end of month
- If not withdrawn earlier
- Combined with session earnings
```

**Pros:**
- Predictable
- Less manual requests

**Cons:**
- Less flexible
- Tutors may need money earlier

---

## 🔄 **Pending vs Active Balance for Transportation**

### **Current Rule:**
- Earnings move to active after 24h (if no complaint/reschedule)

### **Transportation Balance Rules:**

#### **Option 1: Same 24h Rule**
```
Transportation earnings:
├── Pending: After session completion
└── Active: After 24h (same as session earnings)
```

**Pros:**
- ✅ **Consistent with session earnings**
- ✅ **Simple implementation**
- ✅ **Same quality assurance period**

---

#### **Option 2: Immediate Active**
```
Transportation earnings:
└── Active: Immediately after session completion
```

**Pros:**
- Tutors get transportation money faster
- Less complex

**Cons:**
- Inconsistent with session earnings
- No quality assurance period

---

### **RECOMMENDED: Option 1 (Same 24h Rule)**

**Rationale:**
- Consistency with existing system
- Quality assurance applies to entire session (including transportation)
- If session has issues, transportation can be adjusted

---

## 📋 **Database Schema Changes**

### **New Tables/Columns:**

#### **1. `session_payments` Table**
```sql
ALTER TABLE session_payments ADD COLUMN IF NOT EXISTS transportation_cost DECIMAL(10,2);
ALTER TABLE session_payments ADD COLUMN IF NOT EXISTS transportation_earnings DECIMAL(10,2);
ALTER TABLE session_payments ADD COLUMN IF NOT EXISTS is_onsite BOOLEAN DEFAULT false;
```

#### **2. `tutor_earnings` Table**
```sql
ALTER TABLE tutor_earnings ADD COLUMN IF NOT EXISTS transportation_earnings DECIMAL(10,2);
ALTER TABLE tutor_earnings ADD COLUMN IF NOT EXISTS earnings_type TEXT CHECK (earnings_type IN ('session', 'transportation', 'combined'));
```

#### **3. `tutor_transportation_calculations` Table (New)**
```sql
CREATE TABLE tutor_transportation_calculations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES individual_sessions(id),
  tutor_id UUID REFERENCES auth.users(id),
  tutor_home_address TEXT,
  onsite_address TEXT,
  distance_km DECIMAL(10,2),
  duration_minutes INT,
  calculated_cost DECIMAL(10,2), -- 200-1000 XAF
  osrm_route_data JSONB, -- Store routing details
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 🗺️ **Transportation Cost Calculation**

### **Using OSRM Routing:**

1. **Get tutor home address** (from tutor profile)
2. **Get onsite address** (from booking request/session)
3. **Call OSRM API:**
   ```
   GET http://router.project-osrm.org/route/v1/driving/{lon1},{lat1};{lon2},{lat2}
   ```
4. **Extract distance and duration**
5. **Calculate cost:**
   ```dart
   double calculateTransportationCost(double distanceKm, int durationMinutes) {
     // Base cost: 200 XAF
     // Max cost: 1000 XAF
     // Scale based on distance
     
     if (distanceKm <= 2) return 200;
     if (distanceKm >= 10) return 1000;
     
     // Linear scaling: 200 + (distance - 2) * 100
     return 200 + ((distanceKm - 2) / 8) * 800;
   }
   ```

### **Cost Formula:**
```
Base: 200 XAF (0-2 km)
Max: 1000 XAF (10+ km)
Scale: Linear between 2-10 km
```

---

## 💳 **Payment Flow**

### **For Onsite Sessions:**

1. **Parent books onsite session**
2. **System calculates transportation cost** (using OSRM)
3. **Parent sees total:**
   ```
   Session Fee: 5,000 XAF
   Transportation: 600 XAF
   Total: 5,600 XAF
   ```
4. **Parent pays total** (5,600 XAF)
5. **Payment breakdown:**
   ```
   Session Fee (5,000 XAF):
   ├── Platform: 750 XAF (15%)
   └── Tutor: 4,250 XAF (85%)
   
   Transportation (600 XAF):
   ├── Platform: 0 XAF (0%)
   └── Tutor: 600 XAF (100%)
   
   Total Tutor Earnings: 4,850 XAF
   ```

---

## 🔔 **Notifications**

### **For Tutors:**
- "Transportation cost calculated: 600 XAF for session on [date]"
- "Transportation earnings added to pending balance"
- "Transportation earnings moved to active balance"

### **For Parents:**
- "Transportation cost: 600 XAF added to your booking"
- "Total payment: 5,600 XAF (includes 600 XAF transportation)"

---

## ⚠️ **Edge Cases & Considerations**

### **1. Multi-Learner Bookings**
- **Question:** Same tutor, multiple learners at same location?
- **Answer:** One transportation cost (not multiplied)
- **Rationale:** Tutor travels once, teaches multiple learners

### **2. Tutor Home Address Missing**
- **Fallback:** Use tutor's city/region center
- **Or:** Request tutor to add address before accepting onsite bookings

### **3. OSRM API Failure**
- **Fallback:** Use distance-based calculation (if coordinates available)
- **Or:** Default to 500 XAF (mid-range)

### **4. Address Changes**
- **During booking:** Recalculate transportation cost
- **After session:** Use original calculation (locked)

### **5. Rescheduled Sessions**
- **Same location:** Keep original transportation cost
- **Different location:** Recalculate transportation cost

### **6. Cancelled Sessions**
- **Before session:** No transportation cost
- **After session started:** Transportation cost applies (tutor already traveled)

---

## 📊 **Example Scenarios**

### **Scenario 1: Single Onsite Session**
```
Session Fee: 5,000 XAF
Distance: 5 km
Transportation: 500 XAF

Parent Pays: 5,500 XAF
├── Session: 5,000 XAF
└── Transportation: 500 XAF

Tutor Receives:
├── Session earnings: 4,250 XAF (85%)
└── Transportation: 500 XAF (100%)
Total: 4,750 XAF

Platform Receives:
└── 750 XAF (15% of session fee only)
```

---

### **Scenario 2: Multi-Learner Onsite Session**
```
Session Fee: 5,000 XAF (per learner, 2 learners = 10,000 XAF)
Distance: 5 km
Transportation: 500 XAF (ONE cost, not multiplied)

Parent Pays: 10,500 XAF
├── Session: 10,000 XAF
└── Transportation: 500 XAF (shared)

Tutor Receives:
├── Session earnings: 8,500 XAF (85% of 10,000)
└── Transportation: 500 XAF (100%)
Total: 9,000 XAF

Platform Receives:
└── 1,500 XAF (15% of session fee only)
```

---

## ✅ **Recommended Implementation Plan**

### **Phase 1: Core System**
1. ✅ Add transportation cost calculation (OSRM)
2. ✅ Update payment flow to include transportation
3. ✅ Update database schema
4. ✅ Update tutor earnings calculation

### **Phase 2: Balance & Withdrawal**
1. ✅ Update balance system (combined or separate)
2. ✅ Update withdrawal system (flexible)
3. ✅ Add transportation tracking in UI

### **Phase 3: UI/UX**
1. ✅ Show transportation cost in booking flow
2. ✅ Show transportation in tutor wallet
3. ✅ Add withdrawal filters (optional)

---

## ✅ **DECISIONS CONFIRMED**

1. **Cost sharing:** ✅ **Option B (Parent pays full)**
2. **Balance system:** ✅ **Combined (Option 2)**
3. **Withdrawal:** ✅ **Flexible (Option B) - Minimum 5,000 XAF**
4. **Pending/Active:** ✅ **Same 24h rule**
5. **Multi-learner:** ✅ **Single transportation cost (shared)**
6. **Hybrid sessions:** ✅ **Transportation only for onsite sessions (not online)**

---

## 📋 **FINAL SYSTEM DESIGN**

### **Cost Structure:**
```
Parent Pays = Session Fee + Transportation Cost (onsite only)

Session Fee Breakdown:
├── Platform fee: 15% of session fee
└── Tutor earnings: 85% of session fee

Transportation Cost Breakdown (onsite only):
├── Platform fee: 0% (FREE)
└── Tutor transportation earnings: 100% of transportation cost

Hybrid Sessions:
├── Online sessions: No transportation cost
└── Onsite sessions: Transportation cost applies
```

### **Multi-Learner Bookings:**
- **Single transportation cost** (not multiplied)
- **Shared across all learners** at same location
- **Rationale:** Tutor travels once, teaches multiple learners

### **Balance System:**
- **Combined balance** (session + transportation earnings)
- **Same 24h quality assurance** period
- **Can filter by type** (optional UI feature)

### **Withdrawal:**
- **Flexible withdrawal** (any time)
- **Minimum: 5,000 XAF** (combined balance)
- **Tutor choice:** Weekly or monthly

### **Display in Tutor Request Details:**
- ✅ Show transportation cost breakdown (if onsite)
- ✅ Show total parent payment (session + transportation)
- ✅ Show tutor earnings breakdown (session + transportation)
- ✅ Show location type (online/onsite/hybrid)
- ✅ For hybrid: Show which sessions are onsite (transportation applies)
- ✅ Clear indication when transportation cost is included

---

## 📝 **Next Steps**

1. ✅ **Design confirmed**
2. ⏳ **Create detailed implementation plan**
3. ⏳ **Start with Phase 1 (Core System)**
