# 🔧 Admin Dashboard Update Guide

## 📋 **Purpose**
Update the admin dashboard to differentiate between:
- **New tutor applications** (status = 'pending', has_pending_update = FALSE or NULL)
- **Profile updates from approved tutors** (status = 'approved', has_pending_update = TRUE)

---

## 🎯 **Required Changes**

### **1. Update Pending Tutors Query**

**Current Query:**
```typescript
const { data: tutors } = await supabase
  .from('tutor_profiles')
  .select('*')
  .eq('status', 'pending');
```

**Updated Query:**
```typescript
// Fetch all pending tutors (both new applications and updates)
const { data: tutors } = await supabase
  .from('tutor_profiles')
  .select('*')
  .or('status.eq.pending,and(status.eq.approved,has_pending_update.eq.true)');
```

**OR use separate queries for better organization:**
```typescript
// New tutor applications
const { data: newApplications } = await supabase
  .from('tutor_profiles')
  .select('*')
  .eq('status', 'pending')
  .is('has_pending_update', null); // or .eq('has_pending_update', false)

// Profile updates from approved tutors
const { data: pendingUpdates } = await supabase
  .from('tutor_profiles')
  .select('*')
  .eq('status', 'approved')
  .eq('has_pending_update', true);
```

---

### **2. Update UI Display**

**Location:** `/admin/tutors/pending` (or wherever pending tutors are displayed)

**Changes Needed:**

1. **Add Status Badge Differentiation:**
   ```typescript
   // In the tutor card component
   const isPendingUpdate = tutor.status === 'approved' && tutor.has_pending_update === true;
   const displayStatus = isPendingUpdate ? 'Pending Update' : 'Pending';
   const statusColor = isPendingUpdate ? '#4A6FBF' : '#1B2C4F'; // Different shade of blue
   ```

2. **Update Status Badge:**
   ```tsx
   <div className={`px-3 py-1 rounded-full text-xs font-semibold ${
     isPendingUpdate 
       ? 'bg-blue-100 text-blue-700' 
       : 'bg-blue-50 text-blue-900'
   }`}>
     {displayStatus}
   </div>
   ```

3. **Add Visual Indicator:**
   ```tsx
   {isPendingUpdate && (
     <div className="flex items-center gap-1 text-xs text-gray-600">
       <span>🔄</span>
       <span>Profile Update</span>
     </div>
   )}
   ```

---

### **3. Update Dashboard Metrics**

**Location:** `/admin` (main dashboard)

**Current:**
```typescript
const { count: pendingTutors } = await supabase
  .from('tutor_profiles')
  .select('*', { count: 'exact', head: true })
  .eq('status', 'pending');
```

**Updated:**
```typescript
// New applications count
const { count: newApplications } = await supabase
  .from('tutor_profiles')
  .select('*', { count: 'exact', head: true })
  .eq('status', 'pending')
  .is('has_pending_update', null);

// Pending updates count
const { count: pendingUpdates } = await supabase
  .from('tutor_profiles')
  .select('*', { count: 'exact', head: true })
  .eq('status', 'approved')
  .eq('has_pending_update', true);

// Total pending (for main stat card)
const totalPending = (newApplications || 0) + (pendingUpdates || 0);
```

**Display:**
```tsx
<div className="stat-card">
  <h3>Pending Reviews</h3>
  <p className="text-2xl font-bold">{totalPending}</p>
  <div className="text-sm text-gray-600 mt-1">
    {newApplications || 0} new • {pendingUpdates || 0} updates
  </div>
</div>
```

---

### **4. Update Filter/Search**

**Add filter options:**
```tsx
<select onChange={(e) => setFilter(e.target.value)}>
  <option value="all">All Pending</option>
  <option value="new">New Applications</option>
  <option value="updates">Profile Updates</option>
</select>
```

**Filter Logic:**
```typescript
const filteredTutors = tutors.filter(tutor => {
  if (filter === 'new') {
    return tutor.status === 'pending' && !tutor.has_pending_update;
  }
  if (filter === 'updates') {
    return tutor.status === 'approved' && tutor.has_pending_update === true;
  }
  return true; // 'all'
});
```

---

### **5. Update Approval Logic**

**When approving a pending update:**
```typescript
// Approve the update
await supabase
  .from('tutor_profiles')
  .update({
    status: 'approved',
    has_pending_update: false, // Clear the pending update flag
    reviewed_by: adminUserId,
    reviewed_at: new Date().toISOString(),
  })
  .eq('id', tutorId);
```

**When approving a new application:**
```typescript
// Approve new application (same as before)
await supabase
  .from('tutor_profiles')
  .update({
    status: 'approved',
    reviewed_by: adminUserId,
    reviewed_at: new Date().toISOString(),
  })
  .eq('id', tutorId);
```

---

## 📝 **Summary of Changes**

1. ✅ Query both `status = 'pending'` AND `status = 'approved' with has_pending_update = true`
2. ✅ Display "Pending Update" badge for approved tutors with updates
3. ✅ Display "Pending" badge for new applications
4. ✅ Update dashboard metrics to show both counts
5. ✅ Add filter to separate new applications from updates
6. ✅ Update approval logic to clear `has_pending_update` flag

---

## 🎨 **Visual Example**

**Tutor Card with Pending Update:**
```
┌─────────────────────────────────┐
│ [Avatar] John Doe               │
│                                 │
│ 🔄 Profile Update               │
│ [Pending Update] ← Blue badge   │
│                                 │
│ [Approve] [Reject]              │
└─────────────────────────────────┘
```

**Tutor Card with New Application:**
```
┌─────────────────────────────────┐
│ [Avatar] Jane Smith             │
│                                 │
│ [Pending] ← Standard badge     │
│                                 │
│ [Approve] [Reject]              │
└─────────────────────────────────┘
```

---

## ⚠️ **Important Notes**

- Tutors with `has_pending_update = TRUE` remain **visible** on the platform with their current approved data
- Only the **changes** need admin approval
- After approval, set `has_pending_update = FALSE` to clear the flag
- The tutor's status remains `'approved'` throughout the update process

---

## 🔍 **SQL Verification Query**

Run this to see the breakdown:
```sql
SELECT 
  CASE 
    WHEN status = 'pending' AND (has_pending_update IS NULL OR has_pending_update = FALSE) 
      THEN 'New Application'
    WHEN status = 'approved' AND has_pending_update = TRUE 
      THEN 'Pending Update'
    ELSE 'Other'
  END as review_type,
  COUNT(*) as count
FROM tutor_profiles
WHERE (status = 'pending' AND (has_pending_update IS NULL OR has_pending_update = FALSE))
   OR (status = 'approved' AND has_pending_update = TRUE)
GROUP BY review_type;
```

