#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

FLUTTER_PROJECT_PATH="apps/mobile"

echo "================================"
echo " ClinDiary Demo APK Builder"
echo "================================"
echo ""

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter not found. Please install Flutter and add it to PATH."
  exit 1
fi

cd "$FLUTTER_PROJECT_PATH"

echo "Cleaning previous builds..."
flutter clean
flutter pub get

echo ""
echo "Building release APK with local demo mode..."

flutter build apk --release \
  --dart-define=HACKATHON_DEMO_MODE=true \
  --dart-define=LOCAL_ONLY_MODE=true

echo ""
echo "APK built successfully."
echo "Location:"
echo "build/app/outputs/flutter-apk/app-release.apk"

du -h build/app/outputs/flutter-apk/app-release.apk || \
  ls -lh build/app/outputs/flutter-apk/app-release.apk
