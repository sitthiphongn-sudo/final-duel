@echo off
rem Drag your Godot .exe onto this file. Imports the project without the editor window and saves a log to Desktop.
if "%~1"=="" (
 echo Drag the Godot .exe onto this file.
 pause
 exit /b
)
echo Importing... this can take several minutes. Do not close this window.
"%~1" --headless --import --verbose --path "C:\Users\NBMSI\Documents\GitHub\final-duel" > "%USERPROFILE%\Desktop\godot_import_log.txt" 2>&1
echo.
echo Godot finished with code %ERRORLEVEL%
echo Log saved to Desktop: godot_import_log.txt
pause
