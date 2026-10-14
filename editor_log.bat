@echo off
chcp 65001 >nul
if "%~1"=="" (
  echo Drag Godot .exe onto this file.
  pause
  exit /b
)
echo Opening Godot editor with log... when it crashes, send editor_log.txt from Desktop.
"%~1" --editor --path "%~dp0." --verbose > "%USERPROFILE%\Desktop\editor_log.txt" 2>&1
echo.
echo Godot closed with code %errorlevel%
echo Log saved to Desktop: editor_log.txt
pause
