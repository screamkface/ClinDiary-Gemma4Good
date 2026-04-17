# Build release APK with demo mode enabled (Windows)
# Usage: .\build_demo_apk.ps1

param(
    [switch]$SkipClean = $false
)

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "🚀 ClinDiary Demo APK Builder" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Verify Flutter is installed
$flutterPath = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutterPath) {
    Write-Host "❌ Flutter not found. Please install Flutter and add it to PATH." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Flutter found: $flutterPath" -ForegroundColor Green

# Navigate to Flutter project
$flutterProject = Join-Path $PSScriptRoot "apps/mobile"
if (-not (Test-Path $flutterProject)) {
    Write-Host "❌ Flutter project not found at: $flutterProject" -ForegroundColor Red
    exit 1
}

Push-Location $flutterProject

try {
    if (-not $SkipClean) {
        Write-Host ""
        Write-Host "📦 Cleaning previous builds..." -ForegroundColor Yellow
        flutter clean | Out-Null
        flutter pub get | Out-Null
    }

    Write-Host ""
    Write-Host "🔨 Building release APK with demo mode..." -ForegroundColor Yellow
    flutter build apk --release `
      --dart-define=HACKATHON_DEMO_MODE=true `
      --dart-define=API_BASE_URL=http://localhost:8000 `
      -v

    Write-Host ""
    Write-Host "✅ APK built successfully!" -ForegroundColor Green
    Write-Host ""

    $apkPath = "build/app/outputs/flutter-apk/app-release.apk"
    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length / 1MB
        Write-Host "📍 APK location:" -ForegroundColor Cyan
        Write-Host "   $apkPath" -ForegroundColor White
        Write-Host ""
        Write-Host "📊 APK size: $('{0:N1}' -f $apkSize) MB" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "🎯 Next steps:" -ForegroundColor Yellow
    Write-Host "   1. Install on device: adb install $apkPath"
    Write-Host "   2. Test the app (no internet required!)"
    Write-Host "   3. Record demo video"
    Write-Host ""
    Write-Host "Remember: HACKATHON_DEMO_MODE=true means no backend server needed!" -ForegroundColor Green

} finally {
    Pop-Location
}
