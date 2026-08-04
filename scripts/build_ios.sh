#!/bin/bash
# Build iOS (mac only)
# Usage: ./scripts/build_ios.sh [debug|release]

set -e

FLAVOR=${1:-release}

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ iOS builds require macOS"
    exit 1
fi

echo "🔨 Building iOS ($FLAVOR)..."

flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs

cd ios
pod install
cd ..

case $FLAVOR in
  debug)
    # FIXED: --no-codesign is valid for archive/IPA, not for build ios
    flutter build ios --debug --obfuscate --split-debug-info=build/debug-info
    ;;
  release)
    flutter build ipa --release --obfuscate --split-debug-info=build/debug-info
    ;;
  *)
    echo "❌ Unknown flavor: $FLAVOR"
    echo "Usage: $0 [debug|release]"
    exit 1
    ;;
esac

echo "✅ iOS build complete!"
echo "📁 Output: build/ios/ipa/"
