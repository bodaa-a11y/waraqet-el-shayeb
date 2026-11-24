@echo off
chcp 65001 >nul
echo =====================================================
echo  الشايب أونلاين ^| El Shayeb Online — Windows Setup
echo =====================================================
powershell -ExecutionPolicy Bypass -File "%~dp0setup_windows.ps1" %*
