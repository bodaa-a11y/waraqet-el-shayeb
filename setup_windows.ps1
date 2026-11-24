# =============================================================================
# الشايب أونلاين | El Shayeb Online — Windows Setup, Verification & Build Script
# =============================================================================
# Usage (PowerShell):
#   .\setup_windows.ps1
#   .\setup_windows.ps1 -RunEmulators
#   .\setup_windows.ps1 -BuildWeb
#   .\setup_windows.ps1 -BuildApk
# =============================================================================

param (
    [switch]$RunEmulators = $false,
    [switch]$BuildWeb = $false,
    [switch]$BuildApk = $false
)

$ErrorActionPreference = "Stop"
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " الشايب أونلاين | El Shayeb Online — Windows Setup " -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Cyan

# 1. Verify Node.js & Run Canonical TypeScript Engine + Multi-Client E2E Tests
Write-Host "`n[1/5] Running TypeScript Game Engine & Multi-Client E2E Tests (2,300+ rounds)..." -ForegroundColor Green
node --experimental-strip-types --test `
  "functions/test/engine.test.mjs" `
  "functions/test/simulation.test.mjs" `
  "functions/test/security_and_concurrency.test.mjs" `
  "functions/test/archive_a_and_b_unified.test.mjs" `
  "functions/test/multiplayer_functions_e2e.test.mjs"

# 2. Install Cloud Functions dependencies & compile TypeScript
Write-Host "`n[2/5] Installing Cloud Functions npm dependencies and building TypeScript..." -ForegroundColor Green
Push-Location "functions"
npm install
npm run build
Pop-Location

# 3. Run Pure Dart Engine & Contract Verification Tests
Write-Host "`n[3/5] Running Pure Dart Domain, Data Contract & 100-Round Bot Simulation Tests..." -ForegroundColor Green
dart "test/pure_dart_engine_test.dart"

# 4. Run Flutter Pub Get, Static Analysis, and Widget Tests
Write-Host "`n[4/5] Running flutter pub get, flutter analyze, and flutter test..." -ForegroundColor Green
flutter pub get
flutter analyze
flutter test "test/shayeb_engine_and_ui_test.dart"

# 5. Optional Builds / Emulators
if ($BuildWeb) {
    Write-Host "`n[5/5] Building Flutter Web Release..." -ForegroundColor Green
    flutter build web --release
}
if ($BuildApk) {
    Write-Host "`n[5/5] Building Android Release APK..." -ForegroundColor Green
    flutter build apk --release
}
if ($RunEmulators) {
    Write-Host "`n[5/5] Starting Firebase Emulator Suite..." -ForegroundColor Green
    firebase emulators:start
}

Write-Host "`n✅ Setup and verification completed successfully!" -ForegroundColor Green
