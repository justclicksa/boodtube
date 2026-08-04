#!/bin/bash
# Build Android APK
# Usage: ./scripts/build_android.sh [debug|release|profile|split]

set -e

FLAVOR=${1:-release}
OUTPUT_DIR="build/app/outputs/flutter-apk"

echo "🔨 Building Android APK ($FLAVOR)..."

flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs

case $FLAVOR in
  debug)
    # FIXED: --obfuscate is not valid for debug builds
    flutter build apk --debug
    ;;
  release)
    flutter build apk --release --obfuscate --split-debug-info=build/debug-info
    ;;
  profile)
    flutter build apk --profile
    ;;
  split)
    echo "📦 Building split APKs (per ABI)..."
    flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info
    ;;
  *)
    echo "❌ Unknown flavor: $FLAVOR"
    echo "Usage: $0 [debug|release|profile|split]"
    exit 1
    ;;
esac

echo "✅ Build complete!"
echo "📁 Output: $OUTPUT_DIR"
ls -lh $OUTPUT_DIR/ 2>/dev/null || true
