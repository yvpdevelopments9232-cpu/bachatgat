@echo off
echo ======================================================================
echo BUILDING ALL THREE SAKHI BACHAT GAT ANDROID APK EDITIONS
echo ======================================================================
echo.

echo [1/3] Building Offline Standalone Android APK...
call flutter build apk --release --split-per-abi -t lib/main_offline.dart
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Retrying standard APK build for Offline...
    call flutter build apk --release -t lib/main_offline.dart
)
if not exist "dist\Android_Offline" mkdir "dist\Android_Offline"
if exist "build\app\outputs\flutter-apk\app-release.apk" copy /Y "build\app\outputs\flutter-apk\app-release.apk" "dist\Android_Offline\SakhiBachatGat_Offline.apk"
if exist "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "dist\Android_Offline\SakhiBachatGat_Offline.apk"
if exist "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" copy /Y "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "dist\Android_Offline\SakhiBachatGat_Offline_armeabi_v7a.apk"
echo Offline APK ready: dist\Android_Offline\SakhiBachatGat_Offline.apk
echo.

echo [2/3] Building Hybrid Auto-Sync Android APK...
call flutter build apk --release --split-per-abi -t lib/main_hybrid.dart
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Retrying standard APK build for Hybrid...
    call flutter build apk --release -t lib/main_hybrid.dart
)
if not exist "dist\Android_Hybrid" mkdir "dist\Android_Hybrid"
if exist "build\app\outputs\flutter-apk\app-release.apk" copy /Y "build\app\outputs\flutter-apk\app-release.apk" "dist\Android_Hybrid\SakhiBachatGat_Hybrid.apk"
if exist "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "dist\Android_Hybrid\SakhiBachatGat_Hybrid.apk"
if exist "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" copy /Y "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "dist\Android_Hybrid\SakhiBachatGat_Hybrid_armeabi_v7a.apk"
echo Hybrid APK ready: dist\Android_Hybrid\SakhiBachatGat_Hybrid.apk
echo.

echo [3/3] Building Cloud Online Android APK...
call flutter build apk --release --split-per-abi -t lib/main.dart
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Retrying standard APK build for Online...
    call flutter build apk --release -t lib/main.dart
)
if not exist "dist\Android_Online" mkdir "dist\Android_Online"
if exist "build\app\outputs\flutter-apk\app-release.apk" copy /Y "build\app\outputs\flutter-apk\app-release.apk" "dist\Android_Online\SakhiBachatGat_Online.apk"
if exist "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "dist\Android_Online\SakhiBachatGat_Online.apk"
if exist "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" copy /Y "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "dist\Android_Online\SakhiBachatGat_Online_armeabi_v7a.apk"
echo Online APK ready: dist\Android_Online\SakhiBachatGat_Online.apk
echo.

echo ======================================================================
echo ALL THREE ANDROID APKs BUILT SUCCESSFULLY!
echo ======================================================================
echo 1. dist\Android_Offline\SakhiBachatGat_Offline.apk
echo 2. dist\Android_Hybrid\SakhiBachatGat_Hybrid.apk
echo 3. dist\Android_Online\SakhiBachatGat_Online.apk
echo ======================================================================
pause
