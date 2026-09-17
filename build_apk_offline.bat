@echo off
echo ======================================================================
echo BUILDING SAKHI BACHAT GAT - 100% OFFLINE STANDALONE ANDROID APK
echo ======================================================================
echo.

call flutter build apk --release --split-per-abi -t lib/main_offline.dart
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Split-per-abi build returned an error. Retrying standard universal APK build...
    call flutter build apk --release -t lib/main_offline.dart
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Offline APK build failed!
        pause
        exit /b %ERRORLEVEL%
    )
)

if not exist "dist\Android_Offline" mkdir "dist\Android_Offline"
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-release.apk" "dist\Android_Offline\SakhiBachatGat_Offline.apk"
)
if exist "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "dist\Android_Offline\SakhiBachatGat_Offline.apk"
    copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "dist\Android_Offline\SakhiBachatGat_Offline_arm64.apk"
)
if exist "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "dist\Android_Offline\SakhiBachatGat_Offline_armeabi_v7a.apk"
)

echo.
echo ======================================================================
echo OFFLINE APK READY: dist\Android_Offline\SakhiBachatGat_Offline.apk
echo ======================================================================
pause
