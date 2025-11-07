@echo off
REM SmartSplit App Runner Script
REM This script builds and runs the app without Flutter's auto-upgrade issues

echo Building SmartSplit app...
cd android
set JAVA_HOME=C:\Program Files\Java\jdk-17
call gradlew.bat assembleDebug
cd ..

echo Installing app to emulator...
C:\Android\platform-tools\adb.exe -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk

echo Launching app...
C:\Android\platform-tools\adb.exe -s emulator-5554 shell am start -n com.example.smartsplit/.MainActivity

echo.
echo App is running on emulator!
echo To view logs: adb -s emulator-5554 logcat
pause
