@echo off
echo ======================================================================
echo BUILDING SAKHI BACHAT GAT - CLOUD ONLINE ANDROID APK
echo ======================================================================
echo.

call flutter build apk --release --split-per-abi -t lib/main.dart
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Split-per-abi build returned an error. Retrying standard universal APK build...
    call flutter build apk --release -t lib/main.dart
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Online APK build failed!
        pause
        exit /b %ERRORLEVEL%
    )
)

if not exist "dist\Android_Online" mkdir "dist\Android_Online"
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-release.apk" "dist\Android_Online\SakhiBachatGat_Online.apk"
)
if exist "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "dist\Android_Online\SakhiBachatGat_Online.apk"
    copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "dist\Android_Online\SakhiBachatGat_Online_arm64.apk"
)
if exist "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "dist\Android_Online\SakhiBachatGat_Online_armeabi_v7a.apk"
)

echo.
echo ======================================================================
echo ONLINE APK READY: dist\Android_Online\SakhiBachatGat_Online.apk
echo ======================================================================
pause
