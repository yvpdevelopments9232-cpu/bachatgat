@echo off
setlocal enabledelayedexpansion

echo ======================================================================
echo    SAKHI BACHAT GAT - COMPLETE ALL EDITIONS BUILD (WINDOWS + ANDROID)
echo ======================================================================
echo Starting build process at %DATE% %TIME%
echo.

:: 0. Kill any active application processes to release file locks
echo [Step 0/6] Terminating any running application instances...
taskkill /F /IM sakhi_bachat_gat.exe 2>nul
taskkill /F /IM SakhiBachatGat_Hybrid.exe 2>nul
taskkill /F /IM SakhiBachatGat_Offline.exe 2>nul
taskkill /F /IM SakhiBachatGat_Online.exe 2>nul

:: Locate Microsoft Visual C++ 2015-2022 Redistributable CRT DLLs
set "VC_REDIST_CRT=C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Redist\MSVC\14.51.36231\x64\Microsoft.VC145.CRT"
set "VC_REDIST_EXE=C:\Program Files\Microsoft Visual Studio\18\Professional\VC\Redist\MSVC\14.51.36231\vc_redist.x64.exe"

:: Create distribution folders
if not exist "dist\Windows_Hybrid" mkdir "dist\Windows_Hybrid"
if not exist "dist\Android_Hybrid" mkdir "dist\Android_Hybrid"
if not exist "dist\Windows_Offline" mkdir "dist\Windows_Offline"
if not exist "dist\Android_Offline" mkdir "dist\Android_Offline"
if not exist "dist\Windows_Online" mkdir "dist\Windows_Online"
if not exist "dist\Android_Online" mkdir "dist\Android_Online"

echo.
echo ======================================================================
echo [1/6] BUILDING HYBRID EDITION - WINDOWS
echo ======================================================================
call flutter build windows --release -t lib/main_hybrid.dart
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Windows Hybrid build failed!
    goto error
)
echo Deploying Windows Hybrid bundle to dist\Windows_Hybrid...
xcopy /E /I /Y "build\windows\x64\runner\Release\*" "dist\Windows_Hybrid\"
if exist "dist\Windows_Hybrid\SakhiBachatGat_Hybrid.exe" del /f /q "dist\Windows_Hybrid\SakhiBachatGat_Hybrid.exe"
if exist "dist\Windows_Hybrid\sakhi_bachat_gat.exe" ren "dist\Windows_Hybrid\sakhi_bachat_gat.exe" "SakhiBachatGat_Hybrid.exe"
powershell -NoProfile -Command "(Get-Item 'dist\Windows_Hybrid\SakhiBachatGat_Hybrid.exe').LastWriteTime = Get-Date" >nul 2>&1
if not exist "dist\Windows_Hybrid\sqlite3.dll" if exist "build\native_assets\windows\sqlite3.dll" copy /Y "build\native_assets\windows\sqlite3.dll" "dist\Windows_Hybrid\"
if exist "%VC_REDIST_CRT%" copy /Y "%VC_REDIST_CRT%\*.dll" "dist\Windows_Hybrid\" >nul
if exist "%VC_REDIST_EXE%" copy /Y "%VC_REDIST_EXE%" "dist\Windows_Hybrid\" >nul
echo Edition: Windows Hybrid > "dist\Windows_Hybrid\BUILD_INFO.txt"
echo Build Date: %DATE% %TIME% >> "dist\Windows_Hybrid\BUILD_INFO.txt"
echo Version: 8.13+ (Role Selection Modal [Admin/Member] + Member View-Only Controls + Responsive Monthly Collection) >> "dist\Windows_Hybrid\BUILD_INFO.txt"
echo [SUCCESS] Windows Hybrid Ready: dist\Windows_Hybrid\SakhiBachatGat_Hybrid.exe

echo.
echo ======================================================================
echo [2/6] BUILDING HYBRID EDITION - ANDROID APK
echo ======================================================================
call flutter build apk --release --split-per-abi -t lib/main_hybrid.dart
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Android Hybrid build failed!
    goto error
)
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
echo Edition: Android Hybrid > "dist\Android_Hybrid\BUILD_INFO.txt"
echo Build Date: %DATE% %TIME% >> "dist\Android_Hybrid\BUILD_INFO.txt"
echo Version: 8.13+ (Role Selection Modal [Admin/Member] + Member View-Only Controls + Responsive Monthly Collection) >> "dist\Android_Hybrid\BUILD_INFO.txt"
echo [SUCCESS] Android Hybrid Ready: dist\Android_Hybrid\SakhiBachatGat_Hybrid.apk

echo.
echo ======================================================================
echo [3/6] BUILDING OFFLINE EDITION - WINDOWS
echo ======================================================================
call flutter build windows --release -t lib/main_offline.dart
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Windows Offline build failed!
    goto error
)
echo Deploying Windows Offline bundle to dist\Windows_Offline...
xcopy /E /I /Y "build\windows\x64\runner\Release\*" "dist\Windows_Offline\"
if exist "dist\Windows_Offline\SakhiBachatGat_Offline.exe" del /f /q "dist\Windows_Offline\SakhiBachatGat_Offline.exe"
if exist "dist\Windows_Offline\sakhi_bachat_gat.exe" ren "dist\Windows_Offline\sakhi_bachat_gat.exe" "SakhiBachatGat_Offline.exe"
powershell -NoProfile -Command "(Get-Item 'dist\Windows_Offline\SakhiBachatGat_Offline.exe').LastWriteTime = Get-Date" >nul 2>&1
if not exist "dist\Windows_Offline\sqlite3.dll" if exist "build\native_assets\windows\sqlite3.dll" copy /Y "build\native_assets\windows\sqlite3.dll" "dist\Windows_Offline\"
if exist "%VC_REDIST_CRT%" copy /Y "%VC_REDIST_CRT%\*.dll" "dist\Windows_Offline\" >nul
if exist "%VC_REDIST_EXE%" copy /Y "%VC_REDIST_EXE%" "dist\Windows_Offline\" >nul
echo Edition: Windows Offline > "dist\Windows_Offline\BUILD_INFO.txt"
echo Build Date: %DATE% %TIME% >> "dist\Windows_Offline\BUILD_INFO.txt"
echo Version: 8.13+ (Role Selection Modal [Admin/Member] + Member View-Only Controls + Responsive Monthly Collection) >> "dist\Windows_Offline\BUILD_INFO.txt"
echo [SUCCESS] Windows Offline Ready: dist\Windows_Offline\SakhiBachatGat_Offline.exe

echo.
echo ======================================================================
echo [4/6] BUILDING OFFLINE EDITION - ANDROID APK
echo ======================================================================
call flutter build apk --release --split-per-abi -t lib/main_offline.dart
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Android Offline build failed!
    goto error
)
echo Deploying Android Offline APKs to dist\Android_Offline...
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
echo Edition: Android Offline > "dist\Android_Offline\BUILD_INFO.txt"
echo Build Date: %DATE% %TIME% >> "dist\Android_Offline\BUILD_INFO.txt"
echo Version: 8.13+ (Role Selection Modal [Admin/Member] + Member View-Only Controls + Responsive Monthly Collection) >> "dist\Android_Offline\BUILD_INFO.txt"
echo [SUCCESS] Android Offline Ready: dist\Android_Offline\SakhiBachatGat_Offline.apk

echo.
echo ======================================================================
echo [5/6] BUILDING ONLINE EDITION - WINDOWS
echo ======================================================================
call flutter build windows --release -t lib/main.dart
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Windows Online build failed!
    goto error
)
echo Deploying Windows Online bundle to dist\Windows_Online...
xcopy /E /I /Y "build\windows\x64\runner\Release\*" "dist\Windows_Online\"
if exist "dist\Windows_Online\SakhiBachatGat_Online.exe" del /f /q "dist\Windows_Online\SakhiBachatGat_Online.exe"
if exist "dist\Windows_Online\sakhi_bachat_gat.exe" ren "dist\Windows_Online\sakhi_bachat_gat.exe" "SakhiBachatGat_Online.exe"
powershell -NoProfile -Command "(Get-Item 'dist\Windows_Online\SakhiBachatGat_Online.exe').LastWriteTime = Get-Date" >nul 2>&1
if not exist "dist\Windows_Online\sqlite3.dll" if exist "build\native_assets\windows\sqlite3.dll" copy /Y "build\native_assets\windows\sqlite3.dll" "dist\Windows_Online\"
if exist "%VC_REDIST_CRT%" copy /Y "%VC_REDIST_CRT%\*.dll" "dist\Windows_Online\" >nul
if exist "%VC_REDIST_EXE%" copy /Y "%VC_REDIST_EXE%" "dist\Windows_Online\" >nul
echo Edition: Windows Online > "dist\Windows_Online\BUILD_INFO.txt"
echo Build Date: %DATE% %TIME% >> "dist\Windows_Online\BUILD_INFO.txt"
echo Version: 8.13+ (Role Selection Modal [Admin/Member] + Member View-Only Controls + Responsive Monthly Collection) >> "dist\Windows_Online\BUILD_INFO.txt"
echo [SUCCESS] Windows Online Ready: dist\Windows_Online\SakhiBachatGat_Online.exe

echo.
echo ======================================================================
echo [6/6] BUILDING ONLINE EDITION - ANDROID APK
echo ======================================================================
call flutter build apk --release --split-per-abi -t lib/main.dart
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Android Online build failed!
    goto error
)
echo Deploying Android Online APKs to dist\Android_Online...
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
echo Edition: Android Online > "dist\Android_Online\BUILD_INFO.txt"
echo Build Date: %DATE% %TIME% >> "dist\Android_Online\BUILD_INFO.txt"
echo Version: 8.13+ (Role Selection Modal [Admin/Member] + Member View-Only Controls + Responsive Monthly Collection) >> "dist\Android_Online\BUILD_INFO.txt"
echo [SUCCESS] Android Online Ready: dist\Android_Online\SakhiBachatGat_Online.apk

echo.
echo ======================================================================
echo ALL 6 BUILDS COMPLETED SUCCESSFULLY!
echo Finished at %DATE% %TIME%
echo ======================================================================
echo Windows Editions:
echo   1. dist\Windows_Hybrid\SakhiBachatGat_Hybrid.exe
echo   2. dist\Windows_Offline\SakhiBachatGat_Offline.exe
echo   3. dist\Windows_Online\SakhiBachatGat_Online.exe
echo.
echo Android Editions:
echo   1. dist\Android_Hybrid\SakhiBachatGat_Hybrid.apk
echo   2. dist\Android_Offline\SakhiBachatGat_Offline.apk
echo   3. dist\Android_Online\SakhiBachatGat_Online.apk
echo ======================================================================
if "%1"=="/nopause" goto end
pause
:end
exit /b 0

:error
echo ======================================================================
echo [FATAL ERROR] Build process failed with error code %ERRORLEVEL%!
echo ======================================================================
if "%1"=="/nopause" goto end_error
pause
:end_error
exit /b 1
