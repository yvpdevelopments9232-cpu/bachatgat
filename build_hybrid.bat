@echo off
echo ======================================================================
echo BUILDING SAKHI BACHAT GAT - HYBRID AUTO-SYNC EDITION
echo ======================================================================
echo.

echo [1/3] Compiling Windows Hybrid Executable...
taskkill /F /IM sakhi_bachat_gat.exe 2>nul
taskkill /F /IM SakhiBachatGat_Hybrid.exe 2>nul
call flutter build windows --release -t lib/main_hybrid.dart
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Windows Hybrid build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Preparing Distribution Directory...
if not exist "dist\Windows_Hybrid" mkdir "dist\Windows_Hybrid"
xcopy /E /I /Y "build\windows\x64\runner\Release\*" "dist\Windows_Hybrid\"
if exist "dist\Windows_Hybrid\SakhiBachatGat_Hybrid.exe" del /f /q "dist\Windows_Hybrid\SakhiBachatGat_Hybrid.exe"
if exist "dist\Windows_Hybrid\sakhi_bachat_gat.exe" (
    ren "dist\Windows_Hybrid\sakhi_bachat_gat.exe" "SakhiBachatGat_Hybrid.exe"
)

echo.
echo [3/3] Windows Hybrid Bundle Ready!
echo Location: dist\Windows_Hybrid\SakhiBachatGat_Hybrid.exe
echo.
echo Would you like to build Android Hybrid APK as well? (Y/N)
set /p build_apk=
if /i "%build_apk%"=="Y" (
    echo Building Android Hybrid APK...
    call flutter build apk --release --split-per-abi -t lib/main_hybrid.dart
    if not exist "dist\Android_Hybrid" mkdir "dist\Android_Hybrid"
    if exist "build\app\outputs\flutter-apk\app-release.apk" copy /Y "build\app\outputs\flutter-apk\app-release.apk" "dist\Android_Hybrid\SakhiBachatGat_Hybrid.apk"
    if exist "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "dist\Android_Hybrid\SakhiBachatGat_Hybrid.apk"
    echo Location: dist\Android_Hybrid\SakhiBachatGat_Hybrid.apk
)

echo ======================================================================
echo HYBRID BUILD COMPLETED SUCCESSFULLY!
echo ======================================================================
pause
