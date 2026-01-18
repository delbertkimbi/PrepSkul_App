#!/bin/bash

# PrepSkul Test Runner (for use inside prepskul_app directory)
# 
# This script uses absolute paths to avoid Flutter's path resolution issues
# when running tests from inside the prepskul_app directory.

set -e

# Get the absolute path of this script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Running PrepSkul Flutter Tests..."
echo ""

# Use absolute path to avoid Flutter's path doubling issue
flutter test "$SCRIPT_DIR/test/features/messaging/" --no-pub

echo ""
echo "✅ All Flutter tests completed successfully!"

