# Testing Hourly Rate Parsing Fix

## Overview

This document explains how to test the hourly rate parsing fix without manually going through the entire tutor onboarding flow.

## The Problem

Tutors were unable to onboard because the `hourly_rate` field was being incorrectly parsed from formatted strings like "4,000 – 5,000 XAF". The old code was concatenating both numbers (4000 + 5000 = 40005000), which exceeded the database constraint of 1000-50000.

## The Solution

The parsing logic was extracted to a testable utility class (`HourlyRateParser`) that:
- Extracts only the first number from ranges (e.g., "4,000 – 5,000 XAF" → 4000.0)
- Handles "Above X" cases properly
- Validates and clamps values to the valid range (1000-50000)

## Running the Tests

### Run All Tests
```bash
cd prepskul_app
flutter test test/utils/hourly_rate_parser_test.dart
```

### Run with Verbose Output
```bash
flutter test test/utils/hourly_rate_parser_test.dart --verbose
```

### Run with Coverage
```bash
flutter test test/utils/hourly_rate_parser_test.dart --coverage
```

## Test Coverage

The test suite includes **22 test cases** covering:

### Basic Functionality
- ✅ Null and empty string handling
- ✅ Range parsing ("2,000 – 3,000 XAF" → 2000.0)
- ✅ "Above X" cases ("Above 5,000 XAF" → 5000.0)
- ✅ Single values ("4,000 XAF" → 4000.0)
- ✅ Values without commas ("4000" → 4000.0)

### Edge Cases
- ✅ Value clamping (below 1000 → 1000.0, above 50000 → 50000.0)
- ✅ Different dash types (hyphen, en-dash)
- ✅ Decimal values ("2,500.50 XAF" → 2500.50)
- ✅ Whitespace handling
- ✅ Invalid input handling

### Production Scenarios
- ✅ **Critical bug fix verification**: "4,000 – 5,000 XAF" → 4000.0 (NOT 40005000)
- ✅ All dropdown values parse correctly
- ✅ All values are within database constraints (1000-50000)

## Expected Test Results

```
All 22 tests should pass:
✅ 22 tests passed
```

## Manual Testing (Optional)

If you want to verify the fix in the actual app:

1. **Start the app**:
   ```bash
   cd prepskul_app
   flutter run
   ```

2. **Navigate to tutor onboarding** and fill out the form

3. **On the "Expectations" step**, select one of the rate options:
   - "2,000 – 3,000 XAF"
   - "3,000 – 4,000 XAF"
   - "4,000 – 5,000 XAF"
   - "Above 5,000 XAF"

4. **Complete the onboarding** and submit

5. **Verify** that the submission succeeds without the error:
   ```
   Error: hourly_rate must be between 1000 and 50000. Current value: 40005000.00
   ```

## Files Changed

1. **`lib/core/utils/hourly_rate_parser.dart`** - New utility class with parsing logic
2. **`lib/features/tutor/screens/tutor_onboarding_screen.dart`** - Updated to use the utility class
3. **`test/utils/hourly_rate_parser_test.dart`** - Comprehensive test suite

## Integration

The fix is automatically integrated into the onboarding flow. When tutors select their expected rate from the dropdown, the `HourlyRateParser.parseHourlyRate()` method is called to convert the formatted string to a valid numeric value that meets database constraints.

## Verification Checklist

- [x] All unit tests pass (22/22)
- [x] Parsing logic handles all dropdown values correctly
- [x] Values are clamped to valid range (1000-50000)
- [x] Bug fix verified: "4,000 – 5,000 XAF" → 4000.0 (not 40005000)
- [x] Code follows project conventions
- [x] No linting errors














