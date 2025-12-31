#!/bin/bash
# Script to find all potential compilation errors

echo "=== Checking for duplicate class definitions ==="
find lib -name "*.dart" -exec grep -l "^class.*Exception\|^class.*LogService\|^class.*AppTheme\|^class.*SizedBox" {} \;

echo ""
echo "=== Checking for orphaned code blocks (code after class closing braces) ==="
find lib -name "*.dart" -exec sh -c 'file="$1"; lines=$(wc -l < "$file"); last_brace=$(grep -n "^}" "$file" | tail -1 | cut -d: -f1); if [ -n "$last_brace" ] && [ "$last_brace" -lt "$lines" ]; then echo "$file: Class ends at line $last_brace but file has $lines lines"; fi' _ {} \;

echo ""
echo "=== Checking for LogService import conflicts ==="
find lib -name "*.dart" -exec grep -l "import.*auth_service\|import.*log_service" {} \; | while read file; do
  if grep -q "import.*auth_service" "$file" && grep -q "import.*log_service" "$file"; then
    if ! grep -q "hide LogService" "$file"; then
      echo "$file: Missing 'hide LogService' in auth_service import"
    fi
  fi
done

echo ""
echo "=== Checking for Exception redefinitions ==="
grep -r "class Exception\|Exception\s*=\|typedef Exception" lib/ 2>/dev/null || echo "No Exception redefinitions found"

echo ""
echo "=== Done ==="

