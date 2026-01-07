-- ========================================
-- FIND TUTOR: Brian Test
-- ========================================
-- This script searches for a tutor with the name "brian test"
-- and retrieves their email address

-- Search for tutor by name (case-insensitive)
SELECT 
    'Tutor Found' AS status,
    id,
    full_name,
    email,
    phone_number,
    user_type,
    created_at,
    updated_at
FROM profiles
WHERE LOWER(full_name) LIKE '%brian%test%'
   OR LOWER(full_name) LIKE '%brian test%'
   OR LOWER(full_name) = 'brian test'
ORDER BY created_at DESC;

-- Alternative: More specific search if exact match needed
SELECT 
    'Exact Match Search' AS search_type,
    id,
    full_name,
    email,
    phone_number,
    user_type
FROM profiles
WHERE LOWER(TRIM(full_name)) = 'brian test'
  AND user_type = 'tutor'
ORDER BY created_at DESC;

-- If multiple results, show all variations
SELECT 
    'All Variations' AS search_type,
    id,
    full_name,
    email,
    phone_number,
    user_type,
    CASE 
        WHEN LOWER(full_name) = 'brian test' THEN 'Exact Match'
        WHEN LOWER(full_name) LIKE 'brian test%' THEN 'Starts with'
        WHEN LOWER(full_name) LIKE '%brian test%' THEN 'Contains'
        ELSE 'Other'
    END AS match_type
FROM profiles
WHERE (
    LOWER(full_name) LIKE '%brian%test%'
    OR LOWER(full_name) LIKE '%brian test%'
)
AND user_type = 'tutor'
ORDER BY 
    CASE 
        WHEN LOWER(full_name) = 'brian test' THEN 1
        WHEN LOWER(full_name) LIKE 'brian test%' THEN 2
        ELSE 3
    END,
    created_at DESC;

SELECT '✅ Search completed. Review results above.' AS status;

