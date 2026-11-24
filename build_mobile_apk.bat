@echo off
chcp 65001 > nul
echo ============================================================
echo   ورقة الشايب - Waraqet El Shayeb APK Release Builder
echo ============================================================

cd /d "%~dp0"

where flutter > nul 2>&1
if errorlevel 1 (
  if exist "C:\flutter\bin\flutter.bat" (
    set "PATH=C:\flutter\bin;%PATH%"
  ) else (
    echo [ERROR] Flutter CLI was not found on PATH. Install Flutter and retry.
    exit /b 1
  )
)

echo [1/3] Fetching Flutter packages...
call flutter pub get
if errorlevel 1 exit /b 1

echo [2/3] Building Android Release APK (ورقة الشايب)...
call flutter build apk --release ^
  --dart-define=SUPABASE_URL=https://lzmpwjfgrtlypticedic.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_xYJ1BQgVUUiEVmLvcE3q2Q_hmmRTBxX
if errorlevel 1 exit /b 1

if exist "build\app\outputs\flutter-apk\app-release.apk" (
  copy /Y "build\app\outputs\flutter-apk\app-release.apk" "waraqet_el_shayeb_release.apk" > nul
  echo [3/3] DONE! APK ready at:
  echo   %~dp0waraqet_el_shayeb_release.apk
) else (
  echo [ERROR] Build completed without generating app-release.apk
  exit /b 1
)
