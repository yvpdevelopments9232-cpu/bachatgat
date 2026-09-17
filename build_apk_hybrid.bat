@echo off
echo ======================================================================
echo BUILDING SAKHI BACHAT GAT - HYBRID AUTO-SYNC ANDROID APK
echo ======================================================================
echo.

call flutter build apk --release --split-per-abi -t lib/main_hybrid.dart
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Split-per-abi build returned an error. Retrying standard universal APK build...
    call flutter build apk --release -t lib/main_hybrid.dart
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Hybrid APK build failed!
        pause
        exit /b %ERRORLEVEL%
    )
)

if not exist "dist\Android_Hybrid" mkdir "dist\Android_Hybrid"
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-release.apk" "dist\Android_Hybrid\SakhiBachatGat_Hybrid.apk"
)
if exist "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "dist\Android_Hybrid\SakhiBachatGat_Hybrid.apk"
    copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "dist\Android_Hybrid\SakhiBachatGat_Hybrid_arm64.apk"
)
if exist "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "dist\Android_Hybrid\SakhiBachatGat_Hybrid_armeabi_v7a.apk"
)

echo.
echo ======================================================================
echo HYBRID APK READY: dist\Android_Hybrid\SakhiBachatGat_Hybrid.apk
echo ======================================================================
pause
