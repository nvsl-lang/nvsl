@echo off
setlocal
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\nvsl.ps1" %*
exit /b %ERRORLEVEL%
