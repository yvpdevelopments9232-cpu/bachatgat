@echo off
echo ======================================================================
echo BUILDING SAKHI BACHAT GAT - CLOUD ONLINE (SUPABASE) EDITION
echo ======================================================================
echo.

echo [1/3] Compiling Windows Online Executable...
taskkill /F /IM sakhi_bachat_gat.exe 2>nul
taskkill /F /IM SakhiBachatGat_Online.exe 2>nul
call flutter build windows --release -t lib/main.dart
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Windows Online build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Preparing Distribution Directory...
if not exist "dist\Windows_Online" mkdir "dist\Windows_Online"
xcopy /E /I /Y "build\windows\x64\runner\Release\*" "dist\Windows_Online\"
if exist "dist\Windows_Online\SakhiBachatGat_Online.exe" del /f /q "dist\Windows_Online\SakhiBachatGat_Online.exe"
if exist "dist\Windows_Online\sakhi_bachat_gat.exe" (
    ren "dist\Windows_Online\sakhi_bachat_gat.exe" "SakhiBachatGat_Online.exe"
)

echo.
echo [3/3] Windows Online Bundle Ready!
echo Location: dist\Windows_Online\SakhiBachatGat_Online.exe
echo.
echo Would you like to build Android Online APK as well? (Y/N)
set /p build_apk=
if /i "%build_apk%"=="Y" (
    echo Building Android Online APK...
    call flutter build apk --release --split-per-abi -t lib/main.dart
    if not exist "dist\Android_Online" mkdir "dist\Android_Online"
    if exist "build\app\outputs\flutter-apk\app-release.apk" copy /Y "build\app\outputs\flutter-apk\app-release.apk" "dist\Android_Online\SakhiBachatGat_Online.apk"
    if exist "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "dist\Android_Online\SakhiBachatGat_Online.apk"
    echo Location: dist\Android_Online\SakhiBachatGat_Online.apk
)

echo ======================================================================
echo ONLINE BUILD COMPLETED SUCCESSFULLY!
echo ======================================================================
pause
