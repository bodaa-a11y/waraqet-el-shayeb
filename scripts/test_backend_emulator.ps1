# Runs actual Firebase emulators and integration tests; does not connect to production.
# Requires Node.js 22+, Java 21+, Firebase CLI + a completed npm install in functions/.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Install Node.js first (https://nodejs.org/)' }
if (-not (Get-Command java -ErrorAction SilentlyContinue)) { throw 'Install Java 21+ for Firestore Emulator' }
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) { throw 'Install Firebase CLI: npm install -g firebase-tools' }
Write-Host 'Installing and compiling Firebase functions...' -ForegroundColor Cyan
Push-Location functions
try { npm install; if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }; npm run build; if ($LASTEXITCODE -ne 0) { throw 'TypeScript compilation failed' } }
finally { Pop-Location }
Write-Host 'Running REAL Auth, Firestore, Functions and Storage emulator tests...' -ForegroundColor Cyan
$env:SHAYEB_TEST_PROJECT='demo-el-shayeb'
firebase emulators:exec --project demo-el-shayeb --only auth,firestore,functions,storage 'node functions/test/firebase_emulator_smoke.mjs'
if ($LASTEXITCODE -ne 0) { throw 'Firebase Emulator test failed — see diagnostics above' }
Write-Host 'Backend and database integration checks PASSED' -ForegroundColor Green
