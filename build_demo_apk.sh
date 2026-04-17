#!/bin/bash
# Build release APK with demo mode enabled
# Usage: ./build_demo_apk.sh

set -e  # Exit on error

cd "$(dirname "$0")"

FLUTTER_PROJECT_PATH="apps/mobile"

echo "================================"
echo "🚀 ClinDiary Demo APK Builder"
echo "================================"
echo ""

# Verify Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter and add it to PATH."
    exit 1
fi

echo "📦 Cleaning previous builds..."
cd "$FLUTTER_PROJECT_PATH"
flutter clean
flutter pub get

echo ""
echo "🔨 Building release APK with demo mode..."
flutter build apk --release \
  --dart-define=HACKATHON_DEMO_MODE=true \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  -v

echo ""
echo "✅ APK built successfully!"
echo ""
echo "📍 APK location:"
echo "   build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "📊 APK size:"
du -h build/app/outputs/flutter-apk/app-release.apk || ls -lh build/app/outputs/flutter-apk/app-release.apk
echo ""
echo "🎯 Next steps:"
echo "   1. Install on device: adb install build/app/outputs/flutter-apk/app-release.apk"
echo "   2. Test the app (no internet required!)"
echo "   3. Record demo video"
echo ""
echo "Remember: HACKATHON_DEMO_MODE=true means no backend server needed!"
