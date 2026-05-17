param(
    [switch]$SkipClean = $false
)

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host " ClinDiary Demo APK Builder" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

$flutterPath = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutterPath) {
    Write-Host "Flutter not found. Please install Flutter and add it to PATH." -ForegroundColor Red
    exit 1
}

$flutterProject = Join-Path $PSScriptRoot "apps/mobile"
if (-not (Test-Path $flutterProject)) {
    Write-Host "Flutter project not found at: $flutterProject" -ForegroundColor Red
    exit 1
}

Push-Location $flutterProject

try {
    if (-not $SkipClean) {
        Write-Host ""
        Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
        flutter clean
        flutter pub get
    }

    Write-Host ""
    Write-Host "Building release APK with local demo mode..." -ForegroundColor Yellow
    flutter build apk --release `
      --dart-define=HACKATHON_DEMO_MODE=true `
      --dart-define=LOCAL_ONLY_MODE=true

    $apkPath = "build/app/outputs/flutter-apk/app-release.apk"
    Write-Host ""
    Write-Host "APK built successfully." -ForegroundColor Green
    Write-Host "Location:"
    Write-Host $apkPath

    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length / 1MB
        Write-Host "Size: $('{0:N1}' -f $apkSize) MB"
    }
} finally {
    Pop-Location
}
