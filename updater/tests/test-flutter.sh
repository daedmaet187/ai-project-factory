#!/bin/bash
# Regression test for Flutter stack pattern
# Verifies the documented pattern in stacks/mobile/flutter-riverpod.md still works

set -e

echo "=== Flutter Stack Regression Test ==="

# Check Flutter is available
if ! command -v flutter &> /dev/null; then
  echo "❌ Flutter not found in PATH"
  exit 1
fi

# Create temp directory
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
echo "Working in $TMPDIR"

# Create minimal Flutter app
flutter create --org com.test test_app --quiet
cd test_app

# Add dependencies from documented stack
cat > pubspec.yaml << 'EOF'
name: test_app
description: Regression test app
publish_to: 'none'
version: 1.0.0

environment:
  sdk: ^3.5.0
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  go_router: ^14.6.2
  dio: ^5.7.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  riverpod_generator: ^2.6.1
  build_runner: ^2.4.0

flutter:
  uses-material-design: true
EOF

# Get dependencies
echo "Getting dependencies..."
flutter pub get --quiet

# Run analyze
echo "Running flutter analyze..."
if flutter analyze --no-fatal-infos; then
  echo "✅ Analysis passed"
else
  echo "❌ Analysis failed"
  cd /
  rm -rf "$TMPDIR"
  exit 1
fi

# Build (debug mode for speed)
echo "Running debug build..."
if flutter build apk --debug --quiet 2>/dev/null; then
  echo "✅ Build passed"
  RESULT=0
else
  echo "❌ Build failed"
  RESULT=1
fi

# Cleanup
cd /
rm -rf "$TMPDIR"

exit $RESULT
