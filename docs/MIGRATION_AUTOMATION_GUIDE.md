# Database Migration Automation Guide

## Why Manual Migrations?

Currently, migrations are run manually because:
1. **Supabase doesn't auto-run migrations** - They need to be executed in the SQL Editor
2. **Safety** - Manual execution allows review before applying
3. **No Supabase CLI setup** - The project doesn't have automated migration scripts

## Better Approaches

### Option 1: Supabase CLI (Recommended)

**Setup:**
```bash
# Install Supabase CLI
npm install -g supabase

# Link to your project
supabase link --project-ref your-project-ref

# Run migrations automatically
supabase db push
```

**Advantages:**
- Automatic execution
- Version control
- Rollback support
- Team collaboration

**Migration File:**
```bash
# Migrations run in order automatically
supabase/migrations/
  ├── 031_update_trial_sessions_policies.sql
  ├── 032_add_skulmate_character.sql
```

### Option 2: GitHub Actions (CI/CD)

**Create `.github/workflows/migrations.yml`:**
```yaml
name: Run Database Migrations

on:
  push:
    branches: [main]
    paths:
      - 'supabase/migrations/**'

jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: supabase/setup-cli@v1
      - run: supabase db push
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
```

**Advantages:**
- Automatic on code push
- No manual intervention
- Team-wide consistency

### Option 3: Migration Script (Quick Fix)

**Create `scripts/run_migrations.sh`:**
```bash
#!/bin/bash
# Run all pending migrations

MIGRATIONS_DIR="supabase/migrations"
PROJECT_REF="your-project-ref"

for migration in $(ls -1 $MIGRATIONS_DIR/*.sql | sort); do
  echo "Running: $migration"
  supabase db push --file "$migration"
done
```

**Usage:**
```bash
chmod +x scripts/run_migrations.sh
./scripts/run_migrations.sh
```

## Current Migration Status

### Migration 031: Trial Sessions Policies
- **File**: `031_update_trial_sessions_policies.sql`
- **Purpose**: Allows learners/parents to update their trial sessions
- **Status**: Should be run before 032 (if not already run)
- **Dependencies**: None

### Migration 032: skulMate Character
- **File**: `032_add_skulmate_character.sql`
- **Purpose**: Adds character selection to profiles
- **Status**: Can be run after 031
- **Dependencies**: None (independent)

## Running Migrations Manually (Current Method)

### Step 1: Run Migration 031
1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `031_update_trial_sessions_policies.sql`
3. Paste and execute
4. Verify: Check that policy was created

### Step 2: Run Migration 032
1. In same SQL Editor
2. Copy contents of `032_add_skulmate_character.sql`
3. Paste and execute
4. Verify: Check that column was added

### Verification Queries

```sql
-- Check migration 031
SELECT policyname 
FROM pg_policies 
WHERE tablename = 'trial_sessions' 
AND policyname LIKE '%Requesters%';

-- Check migration 032
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name = 'skulmate_character_id';
```

## Recommendation

**Short term**: Continue manual execution (safe, controlled)
**Long term**: Set up Supabase CLI for automation

The manual approach is actually **safer** for production databases as it allows:
- Review before execution
- Testing in staging first
- Rollback if issues occur
- Team coordination






## Why Manual Migrations?

Currently, migrations are run manually because:
1. **Supabase doesn't auto-run migrations** - They need to be executed in the SQL Editor
2. **Safety** - Manual execution allows review before applying
3. **No Supabase CLI setup** - The project doesn't have automated migration scripts

## Better Approaches

### Option 1: Supabase CLI (Recommended)

**Setup:**
```bash
# Install Supabase CLI
npm install -g supabase

# Link to your project
supabase link --project-ref your-project-ref

# Run migrations automatically
supabase db push
```

**Advantages:**
- Automatic execution
- Version control
- Rollback support
- Team collaboration

**Migration File:**
```bash
# Migrations run in order automatically
supabase/migrations/
  ├── 031_update_trial_sessions_policies.sql
  ├── 032_add_skulmate_character.sql
```

### Option 2: GitHub Actions (CI/CD)

**Create `.github/workflows/migrations.yml`:**
```yaml
name: Run Database Migrations

on:
  push:
    branches: [main]
    paths:
      - 'supabase/migrations/**'

jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: supabase/setup-cli@v1
      - run: supabase db push
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
```

**Advantages:**
- Automatic on code push
- No manual intervention
- Team-wide consistency

### Option 3: Migration Script (Quick Fix)

**Create `scripts/run_migrations.sh`:**
```bash
#!/bin/bash
# Run all pending migrations

MIGRATIONS_DIR="supabase/migrations"
PROJECT_REF="your-project-ref"

for migration in $(ls -1 $MIGRATIONS_DIR/*.sql | sort); do
  echo "Running: $migration"
  supabase db push --file "$migration"
done
```

**Usage:**
```bash
chmod +x scripts/run_migrations.sh
./scripts/run_migrations.sh
```

## Current Migration Status

### Migration 031: Trial Sessions Policies
- **File**: `031_update_trial_sessions_policies.sql`
- **Purpose**: Allows learners/parents to update their trial sessions
- **Status**: Should be run before 032 (if not already run)
- **Dependencies**: None

### Migration 032: skulMate Character
- **File**: `032_add_skulmate_character.sql`
- **Purpose**: Adds character selection to profiles
- **Status**: Can be run after 031
- **Dependencies**: None (independent)

## Running Migrations Manually (Current Method)

### Step 1: Run Migration 031
1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `031_update_trial_sessions_policies.sql`
3. Paste and execute
4. Verify: Check that policy was created

### Step 2: Run Migration 032
1. In same SQL Editor
2. Copy contents of `032_add_skulmate_character.sql`
3. Paste and execute
4. Verify: Check that column was added

### Verification Queries

```sql
-- Check migration 031
SELECT policyname 
FROM pg_policies 
WHERE tablename = 'trial_sessions' 
AND policyname LIKE '%Requesters%';

-- Check migration 032
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name = 'skulmate_character_id';
```

## Recommendation

**Short term**: Continue manual execution (safe, controlled)
**Long term**: Set up Supabase CLI for automation

The manual approach is actually **safer** for production databases as it allows:
- Review before execution
- Testing in staging first
- Rollback if issues occur
- Team coordination







