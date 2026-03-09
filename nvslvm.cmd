@echo off
setlocal
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\nvslvm.ps1" %*
exit /b %ERRORLEVEL%
