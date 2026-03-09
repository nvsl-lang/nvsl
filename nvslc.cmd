@echo off
setlocal
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\nvslc.ps1" %*
exit /b %ERRORLEVEL%
