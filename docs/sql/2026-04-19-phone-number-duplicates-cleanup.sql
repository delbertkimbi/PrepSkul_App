-- PrepSkul admin script: detect + safely clean duplicate profiles.phone_number rows
-- Date: 2026-04-19
-- Usage:
--   1) Run SECTION A and B first (read-only diagnostics).
--   2) If results look correct, run SECTION C inside a transaction.
--   3) Optionally enforce uniqueness with SECTION D.

-- =========================================================
-- SECTION A: Detect duplicates (read-only)
-- =========================================================

-- Duplicate phone numbers and counts
SELECT
  phone_number,
  COUNT(*) AS row_count
FROM public.profiles
WHERE phone_number IS NOT NULL
  AND TRIM(phone_number) <> ''
GROUP BY phone_number
HAVING COUNT(*) > 1
ORDER BY row_count DESC, phone_number;

-- Full rows for duplicate phone numbers (oldest first)
WITH dupes AS (
  SELECT phone_number
  FROM public.profiles
  WHERE phone_number IS NOT NULL
    AND TRIM(phone_number) <> ''
  GROUP BY phone_number
  HAVING COUNT(*) > 1
)
SELECT
  p.id,
  p.full_name,
  p.user_type,
  p.phone_number,
  p.created_at,
  p.updated_at
FROM public.profiles p
JOIN dupes d ON d.phone_number = p.phone_number
ORDER BY p.phone_number, p.created_at ASC, p.id ASC;

-- =========================================================
-- SECTION B: Preview canonical rows (read-only)
-- Rule: keep the oldest row per phone_number.
-- =========================================================
WITH ranked AS (
  SELECT
    p.id,
    p.phone_number,
    p.created_at,
    ROW_NUMBER() OVER (
      PARTITION BY p.phone_number
      ORDER BY p.created_at ASC, p.id ASC
    ) AS rn
  FROM public.profiles p
  WHERE p.phone_number IS NOT NULL
    AND TRIM(p.phone_number) <> ''
)
SELECT
  phone_number,
  id AS canonical_profile_id,
  created_at AS canonical_created_at
FROM ranked
WHERE rn = 1
  AND phone_number IN (
    SELECT phone_number
    FROM public.profiles
    WHERE phone_number IS NOT NULL
      AND TRIM(phone_number) <> ''
    GROUP BY phone_number
    HAVING COUNT(*) > 1
  )
ORDER BY phone_number;

-- =========================================================
-- SECTION C: Safe cleanup (write)
-- Strategy:
--   - Keep canonical row (oldest) for each phone.
--   - Null out phone_number on non-canonical rows.
--   - Keep user rows intact (no delete), so FK integrity is preserved.
-- =========================================================

BEGIN;

-- Optional: backup affected rows before update
CREATE TABLE IF NOT EXISTS public.profiles_phone_cleanup_backup_20260419 AS
SELECT *
FROM public.profiles
WHERE phone_number IN (
  SELECT phone_number
  FROM public.profiles
  WHERE phone_number IS NOT NULL
    AND TRIM(phone_number) <> ''
  GROUP BY phone_number
  HAVING COUNT(*) > 1
);

WITH ranked AS (
  SELECT
    p.id,
    p.phone_number,
    ROW_NUMBER() OVER (
      PARTITION BY p.phone_number
      ORDER BY p.created_at ASC, p.id ASC
    ) AS rn
  FROM public.profiles p
  WHERE p.phone_number IS NOT NULL
    AND TRIM(p.phone_number) <> ''
),
to_clear AS (
  SELECT id
  FROM ranked
  WHERE rn > 1
)
UPDATE public.profiles p
SET
  phone_number = NULL,
  updated_at = NOW()
FROM to_clear c
WHERE p.id = c.id;

-- Verify duplicates cleared
SELECT
  phone_number,
  COUNT(*) AS row_count
FROM public.profiles
WHERE phone_number IS NOT NULL
  AND TRIM(phone_number) <> ''
GROUP BY phone_number
HAVING COUNT(*) > 1;

COMMIT;

-- =========================================================
-- SECTION D (Optional): enforce uniqueness going forward
-- =========================================================

-- Run only after SECTION C verification is clean.
-- This allows multiple NULL values while enforcing unique non-null phones.
CREATE UNIQUE INDEX IF NOT EXISTS profiles_unique_phone_number_not_null
ON public.profiles (phone_number)
WHERE phone_number IS NOT NULL AND TRIM(phone_number) <> '';

