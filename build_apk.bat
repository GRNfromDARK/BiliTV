@echo off
REM BiliTV APK 编译脚本（优化版）
REM 使用 split-per-abi 一次编译所有架构

cd /d C:\Users\Kirin\OneDrive\Code\BiliTV

echo ========================================
echo Building all ABIs...
echo ========================================
call flutter build apk --release --split-per-abi --obfuscate --split-debug-info=./build/app/outputs/symbols
if errorlevel 1 goto error

echo ========================================
echo Copying APK files...
echo ========================================
copy /Y "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "\\192.168.1.1\docker\DockerData\BiliTv_UpdateService\releases\v7a.apk"
copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "\\192.168.1.1\docker\DockerData\BiliTv_UpdateService\releases\v8a.apk"

echo ========================================
echo Done!
echo v7a.apk and v8a.apk copied to releases folder
echo ========================================
goto end

:error
echo Build failed!
exit /b 1

:end
pause