# Test Runner Guide

## Quick Start

### Run All Messaging Tests

From the **project root** (`/Users/user/Desktop/PrepSkul`):

```bash
# Option 1: Use the test runner script
./run_tests.sh

# Option 2: Manual command
cd prepskul_app && flutter test test/features/messaging/
```

### Run Tests from Inside `prepskul_app` Directory

If you're already inside the `prepskul_app` directory, **use the local test runner script**:

```bash
./run_tests.sh
```

This script uses absolute paths to avoid Flutter's path resolution issues.

**Alternative methods:**

**Method 1: Use absolute path**
```bash
flutter test /Users/user/Desktop/PrepSkul/prepskul_app/test/features/messaging/
```

**Method 2: Go back to project root first**
```bash
cd .. && cd prepskul_app && flutter test test/features/messaging/
```

## Test Categories

### Model Tests
```bash
cd prepskul_app && flutter test test/features/messaging/models/
```

### Service Tests
```bash
cd prepskul_app && flutter test test/features/messaging/services/
```

### Widget Tests
```bash
cd prepskul_app && flutter test test/features/messaging/widgets/
```

### Integration Tests
```bash
cd prepskul_app && flutter test test/features/messaging/integration/
```

### Run Specific Test File

**From inside `prepskul_app` directory:**
```bash
flutter test test/features/messaging/models/message_model_test.dart
```
*(Note: Running individual test files works fine from inside the directory)*

**From project root:**
```bash
cd prepskul_app && flutter test test/features/messaging/models/message_model_test.dart
```

## Backend Tests (Jest)

From the **project root**:

```bash
cd PrepSkul_Web && npm test
```

Or from inside `PrepSkul_Web`:

```bash
npm test
```

### Run Specific Backend Test
```bash
cd PrepSkul_Web && npm test -- test/__tests__/message-filter-service.test.ts
```

## Why the Path Issue?

Flutter's test runner changes the working directory when you're already inside `prepskul_app`, which can cause path resolution issues. Running from the project root with `cd prepskul_app && flutter test` ensures the paths resolve correctly.

## Test Coverage

- **Flutter Tests**: 56 tests (all passing)
  - Model tests: 18 tests
  - Service tests: 21 tests
  - Widget tests: 4 tests
  - Integration tests: 8 tests

- **Backend Tests**: 75 tests (all passing)
  - Message filter service: 17 tests
  - Other services: 58 tests

## Troubleshooting

### Issue: "Does not exist" error with double path (e.g., `/prepskul_app/prepskul_app/test/...`)

This happens when Flutter's test runner changes the working directory and doubles the path. 

**Solution 1 (Recommended): Use the local test runner script**
```bash
# From inside prepskul_app directory
./run_tests.sh
```

**Solution 2: Use absolute path**
```bash
# From inside prepskul_app directory
flutter test /Users/user/Desktop/PrepSkul/prepskul_app/test/features/messaging/
```

**Solution 3: Run from project root**
```bash
cd /Users/user/Desktop/PrepSkul
cd prepskul_app && flutter test test/features/messaging/
```

### Issue: Tests not found

**Solution**: Make sure you're in the correct directory and the test files exist:
```bash
ls -la prepskul_app/test/features/messaging/
```

### Issue: Flutter not found

**Solution**: Make sure Flutter is in your PATH:
```bash
which flutter
flutter --version
```

