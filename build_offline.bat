@echo off
echo ======================================================================
echo BUILDING SAKHI BACHAT GAT - 100%% OFFLINE STANDALONE EDITION
echo ======================================================================
echo.

echo [1/3] Compiling Windows Offline Executable...
taskkill /F /IM sakhi_bachat_gat.exe 2>nul
taskkill /F /IM SakhiBachatGat_Offline.exe 2>nul
call flutter build windows --release -t lib/main_offline.dart
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Windows Offline build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Preparing Distribution Directory...
if not exist "dist\Windows_Offline" mkdir "dist\Windows_Offline"
xcopy /E /I /Y "build\windows\x64\runner\Release\*" "dist\Windows_Offline\"
if exist "dist\Windows_Offline\SakhiBachatGat_Offline.exe" del /f /q "dist\Windows_Offline\SakhiBachatGat_Offline.exe"
if exist "dist\Windows_Offline\sakhi_bachat_gat.exe" (
    ren "dist\Windows_Offline\sakhi_bachat_gat.exe" "SakhiBachatGat_Offline.exe"
)

echo.
echo [3/3] Windows Offline Bundle Ready!
echo Location: dist\Windows_Offline\SakhiBachatGat_Offline.exe
echo.
echo Would you like to build Android Offline APK as well? (Y/N)
set /p build_apk=
if /i "%build_apk%"=="Y" (
    echo Building Android Offline APK...
    call flutter build apk --release --split-per-abi -t lib/main_offline.dart
    if not exist "dist\Android_Offline" mkdir "dist\Android_Offline"
    if exist "build\app\outputs\flutter-apk\app-release.apk" copy /Y "build\app\outputs\flutter-apk\app-release.apk" "dist\Android_Offline\SakhiBachatGat_Offline.apk"
    if exist "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "dist\Android_Offline\SakhiBachatGat_Offline.apk"
    echo Location: dist\Android_Offline\SakhiBachatGat_Offline.apk
)

echo ======================================================================
echo OFFLINE BUILD COMPLETED SUCCESSFULLY!
echo ======================================================================
pause
