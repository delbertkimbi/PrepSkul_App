#!/bin/bash
# Script to remove duplicate class definitions from Dart files

cd "$(dirname "$0")/.." || exit 1

# Function to find and remove duplicate classes
fix_duplicate_classes() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return
    fi
    
    # Find all class declarations
    local class_lines=$(grep -n "^class " "$file" | cut -d: -f1)
    
    if [ -z "$class_lines" ]; then
        return
    fi
    
    # Count occurrences of each class name
    local class_names=$(grep "^class " "$file" | sed 's/class \([A-Za-z0-9_]*\).*/\1/' | sort | uniq -d)
    
    if [ -z "$class_names" ]; then
        return
    fi
    
    echo "Found duplicate classes in $file: $class_names"
    
    # For each duplicate class, keep only the first occurrence
    for class_name in $class_names; do
        local first_line=$(grep -n "^class $class_name" "$file" | head -1 | cut -d: -f1)
        local all_lines=$(grep -n "^class $class_name" "$file" | cut -d: -f1)
        
        # Find the end of the first class (next class or end of file)
        local next_class_line=$(grep -n "^class " "$file" | awk -v first="$first_line" '$1 > first {print $1; exit}')
        if [ -z "$next_class_line" ]; then
            next_class_line=$(wc -l < "$file")
        fi
        
        # Remove all duplicate classes after the first one
        for dup_line in $all_lines; do
            if [ "$dup_line" -gt "$first_line" ]; then
                # Find end of this duplicate class
                local dup_end=$(grep -n "^class " "$file" | awk -v dup="$dup_line" '$1 > dup {print $1; exit}')
                if [ -z "$dup_end" ]; then
                    dup_end=$(wc -l < "$file")
                fi
                
                # Remove lines from dup_line to dup_end-1
                sed -i.bak "${dup_line},$((dup_end-1))d" "$file"
                rm -f "${file}.bak"
            fi
        done
    done
}

# Find all Dart files with duplicate class definitions
find lib -name "*.dart" -type f | while read -r file; do
    # Count class declarations
    class_count=$(grep -c "^class " "$file" 2>/dev/null || echo "0")
    if [ "$class_count" -gt 1 ]; then
        # Check for duplicate class names
        duplicate_classes=$(grep "^class " "$file" | sed 's/class \([A-Za-z0-9_]*\).*/\1/' | sort | uniq -d)
        if [ -n "$duplicate_classes" ]; then
            echo "Processing $file..."
            fix_duplicate_classes "$file"
        fi
    fi
done

echo "Done fixing duplicate classes."

