# Run in a SECOND Windows PowerShell after scripts/run_emulators.ps1.
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter not on PATH' }
# In case ZIP does not include generated platform folders.
if (!(Test-Path '.metadata') -or !(Test-Path 'web/index.html')) { flutter create . --platforms=web --project-name el_shayeb_online; if ($LASTEXITCODE -ne 0) { throw 'flutter create failed' } }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_PROJECT_ID=demo-el-shayeb --dart-define=FIREBASE_FUNCTIONS_REGION=europe-west1
