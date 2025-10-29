#!/bin/bash

# PrepSkul Codebase Cleanup Script
# This script safely removes unused/duplicate files

echo "🧹 Starting PrepSkul Codebase Cleanup..."
echo ""

# Track deleted files
DELETED=0
FAILED=0

# Function to safely delete a file
safe_delete() {
    if [ -f "$1" ]; then
        rm "$1"
        if [ $? -eq 0 ]; then
            echo "✅ Deleted: $1"
            ((DELETED++))
        else
            echo "❌ Failed to delete: $1"
            ((FAILED++))
        fi
    else
        echo "⏭️  Not found (already deleted?): $1"
    fi
}

# Function to safely delete a directory
safe_delete_dir() {
    if [ -d "$1" ]; then
        rm -rf "$1"
        if [ $? -eq 0 ]; then
            echo "✅ Deleted directory: $1"
            ((DELETED++))
        else
            echo "❌ Failed to delete directory: $1"
            ((FAILED++))
        fi
    else
        echo "⏭️  Not found (already deleted?): $1"
    fi
}

echo "📁 Phase 1: Removing OLD AUTH screens..."
safe_delete "lib/features/auth/screens/login_screen.dart"
safe_delete "lib/features/auth/screens/signup_screen.dart"

echo ""
echo "📁 Phase 2: Removing DUPLICATE TUTOR screens..."
safe_delete "lib/features/tutor/screens/tutor_onboarding_screen_OLD_BACKUP.dart"
safe_delete "lib/features/tutor/screens/tutor_onboarding_screen_REFACTORED.dart"
safe_delete "lib/features/tutor/screens/tutor_onboarding_screen_new.dart"
safe_delete "lib/features/tutor/screens/tutor_dashboard_screen.dart"

echo ""
echo "📁 Phase 3: Removing REFACTORED WIDGETS (not integrated)..."
safe_delete_dir "lib/features/tutor/widgets"
safe_delete_dir "lib/features/tutor/models"

echo ""
echo "📁 Phase 4: Removing DUPLICATE MODELS..."
safe_delete_dir "lib/models"

echo ""
echo "📁 Phase 5: Removing UNUSED CORE..."
safe_delete_dir "lib/core/responsive"
safe_delete "lib/core/widgets/neumorphic_widgets.dart"
safe_delete "lib/core/widgets/base_survey_widget.dart"
safe_delete "lib/core/services/whatsapp_service.dart"

echo ""
echo "📁 Phase 6: Removing UNUSED PROFILE screens/widgets..."
safe_delete "lib/features/profile/screens/detailed_profile_survey.dart"
safe_delete "lib/features/profile/screens/simple_profile_setup.dart"
safe_delete_dir "lib/features/profile/widgets"

echo ""
echo "📁 Phase 7: Removing PLACEHOLDER FEATURES..."
safe_delete_dir "lib/features/booking"
safe_delete_dir "lib/features/experience_flow"
safe_delete "lib/features/tutor/screens/simple_tutor_discovery.dart"

echo ""
echo "📁 Phase 8: Removing UNUSED ONBOARDING..."
safe_delete "lib/features/onboarding/screens/onboarding_screen.dart"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Cleanup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Files/Folders Deleted: $DELETED"
echo "❌ Failed Deletions: $FAILED"
echo ""
echo "🔍 Next Steps:"
echo "1. Run: flutter clean"
echo "2. Run: flutter pub get"
echo "3. Run: flutter analyze"
echo "4. Test all flows to ensure nothing broke"
echo ""


