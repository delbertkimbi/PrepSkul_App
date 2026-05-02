# Multi-Learner Discount Algorithm

## Overview
Multi-learner discounts apply **ONLY to recurring/normal tutor bookings** when a parent books sessions for 2+ children with the same tutor. **Trial sessions have fixed pricing regardless of learner count.**

## Database Configuration
Discount rules are stored in `multi_learner_discount_rules` table and are **admin-configurable**:

| learner_ordinal | discount_percent | Description |
|----------------|------------------|-------------|
| 2 | 15% | 2nd learner discount |
| 3 | 20% | 3rd learner and beyond |

**Default values:**
- 2nd learner: 15% off
- 3rd+ learners: 20% off

## Algorithm

### Step 1: Determine Discount Percent for Each Learner
For each learner ordinal (1st, 2nd, 3rd, etc.), find the discount percent:

```dart
discountPercent = highest rule where learner_ordinal <= current_ordinal
```

**Rules:**
- 1st learner: Always 0% (full price)
- 2nd learner: Use rule for `learner_ordinal = 2` (default: 15%)
- 3rd learner: Use rule for `learner_ordinal = 3` (default: 20%)
- 4th+ learners: Use rule for `learner_ordinal = 3` (default: 20%)

### Step 2: Calculate Monthly Total
For each learner, calculate their monthly total:

```dart
learnerMonthlyTotal = baseMonthlyTotal * (1 - discountPercent / 100)
roundedMonthlyTotal = round(learnerMonthlyTotal / 100) * 100  // Round to nearest 100 XAF
```

### Step 3: Sum All Learners
```dart
totalMonthlyTotal = sum of all roundedMonthlyTotal for each learner
```

## Example Calculation

**Scenario:** Parent books recurring sessions for 3 children
- Base monthly total per learner: 10,000 XAF
- Discount rules: 2nd = 15%, 3rd+ = 20%

**Calculation:**
1. **1st learner:**
   - Discount: 0%
   - Monthly total: 10,000 XAF

2. **2nd learner:**
   - Discount: 15%
   - Monthly total: 10,000 × (1 - 0.15) = 8,500 XAF
   - Rounded: 8,500 XAF

3. **3rd learner:**
   - Discount: 20%
   - Monthly total: 10,000 × (1 - 0.20) = 8,000 XAF
   - Rounded: 8,000 XAF

**Total:** 10,000 + 8,500 + 8,000 = **26,500 XAF/month**

## Implementation

### Code Location
- **Service:** `PricingService.calculateMultiLearnerMonthlyTotal()`
- **Database:** `multi_learner_discount_rules` table
- **Migration:** `051_multi_learner_discount_rules.sql`

### Key Methods

```dart
// Get discount rules from database
PricingService.getMultiLearnerDiscountRules()

// Calculate total for N learners
PricingService.calculateMultiLearnerMonthlyTotal(
  baseMonthlyTotal: 10000.0,
  learnerCount: 3,
)
```

## Important Notes

1. **Discounts apply by ordinal position**, not by which specific child is selected
2. **Rounding:** All amounts are rounded to nearest 100 XAF for cleaner pricing
3. **Admin-configurable:** Discount percentages can be changed by admins in the database
4. **Single learner:** No discount applied (returns baseMonthlyTotal)
5. **Trial sessions:** Fixed pricing regardless of learner count (no discounts)

## Future Enhancements

- Per-subject discounts
- Volume-based discounts (e.g., 4+ learners get 25% off)
- Time-based discounts (e.g., longer commitments)
