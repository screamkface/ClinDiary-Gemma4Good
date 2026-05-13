# ClinDiary - Gemma 4 Good Hackathon Release Guide

## 🚀 Building the Release APK (Demo Mode)

This guide explains how to build the release APK for the Gemma 4 Good Hackathon using the local-first demo flow.

### Prerequisites

- Flutter 3.9+ installed
- Android SDK 26+ 
- Keystore generated (see below)

### Step 1: Verify Keystore

The release keystore has been generated at:
```
apps/mobile/android/app-release.jks
```

And `key.properties` is configured with signing credentials.

### Step 2: Build Release APK with Demo Mode

```bash
cd apps/mobile

# Build with local demo mode enabled (no backend required)
flutter build apk --release \
  --dart-define=HACKATHON_DEMO_MODE=true \
  --dart-define=LOCAL_ONLY_MODE=true \
  --dart-define=API_BASE_URL=http://localhost:8000

# Output:
# build/app/outputs/flutter-apk/app-release.apk (≈50-60 MB)
```

### Step 3: Install on Device

```bash
# Via adb
adb install build/app/outputs/flutter-apk/app-release.apk

# Or from repository root
powershell -ExecutionPolicy Bypass -File build_demo_apk.ps1
```

---

## 📱 What's Included in Demo Mode

When `HACKATHON_DEMO_MODE=true` and `LOCAL_ONLY_MODE=true`, the app uses a local-only demo session and loads deterministic demo seed data.

### ✅ Demo Data Features

1. **Profile**: Demo user scope with realistic health profile data
2. **Daily Entries**: 3 sample days with vitals, symptoms, AI recaps
3. **Clinical Documents**: Sample blood tests, ECG, GP consultation notes
4. **Screenings**: Blood pressure, cholesterol, glucose
5. **Vaccinations**: COVID-19, Influenza, Tetanus records
6. **Visit Recommendations**: Annual physical, dental, eye exams

### 🧠 AI/Gemma Features (Real)

- **Real Gemma 4 E2B LiteRT Model**: Runs actual AI recap generation
- **Local On-Device Processing**: No cloud calls, privacy-first
- **Document Analysis**: AI interprets clinical documents

### 📊 Backend Bypass

In demo mode:
- ✅ No internet required for core diary flow
- ✅ No backend server needed
- ✅ No authentication required
- ✅ All features functional

---

## 🎮 Demo App Flow (3-5 minutes)

1. **App Launch** → Opens local-only flow and demo workspace
2. **Home Screen** → Shows today's health status
3. **Daily Check-in** → Trigger AI Recap with Gemma 4
4. **Documents Tab** → View sample clinical documents
5. **History/Check-ups** → See past records
6. **Insights** → Show AI analysis powered by Gemma 4

---

## 🔧 Build Flags Reference

```bash
# Enable hackathon demo mode (loads demo data)
--dart-define=HACKATHON_DEMO_MODE=true

# Keep local-only mode enabled
--dart-define=LOCAL_ONLY_MODE=true

# Set API base URL (ignored in local demo mode)
--dart-define=API_BASE_URL=http://localhost:8000

# Enable Google Auth (optional, not needed for demo)
--dart-define=GOOGLE_AUTH_CLIENT_ID=your-client-id

# Debug/release example
flutter build apk --release --dart-define=HACKATHON_DEMO_MODE=true --dart-define=LOCAL_ONLY_MODE=true
```

---

## 📦 APK File

**Location**: `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`

**Size**: depends on packaging and ABI split settings
**Signing**: Release keystore (`app-release.jks`)
**Target**: Android 8.0+ (API 26+)

---

## 🎬 Demo Data Source

Demo data is defined in:
```
apps/mobile/lib/app/core/demo_seed_data.dart
```

To add more demo data:
1. Update structures and seed payloads in `DemoSeedData`
2. Update providers/repositories only when new domains need demo fallback
3. Rebuild APK

---

## 🔐 Security Notes

- Demo keystore uses non-production password (for hackathon only)
- No real user data is stored
- Core demo flow is local-only; backend URL is not used by default
- Gemma model runs entirely on-device
- App lock can be enabled from Settings (PIN + optional biometrics)

---

## ❓ Troubleshooting

### APK won't install
```bash
# Clear existing install
adb uninstall it.clindiary.clindiary

# Then install
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Gemma model not loading
- Ensure device has >2GB free storage
- Check `on_device_model_screen.dart` for model download status

### Demo data not showing
- Verify `HACKATHON_DEMO_MODE=true` in build flag
- Verify `LOCAL_ONLY_MODE=true` in build flag
- Check logcat: `flutter logs`

---

## 📋 Submission Checklist

- [ ] APK builds successfully: `flutter build apk --release`
- [ ] APK installs on multiple Android devices
- [ ] Demo data loads without internet
- [ ] Gemma 4 AI features work (recaps, document analysis)
- [ ] Video demo recorded (3 min max)
- [ ] Code pushed to GitHub (public)
- [ ] Writeup prepared (1,500 words max)

---

## 🚀 Next Steps

1. Build APK: Follow Step 2 above
2. Test on real device
3. Record demo video
4. Upload APK to GitHub Releases
5. Create Kaggle Writeup with all links

---

**Good luck with the Gemma 4 Good Hackathon! 🎉**

For questions, see the main [README.md](../../README.md) or project architecture docs.
