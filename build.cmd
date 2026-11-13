@echo off
setlocal
cd /d "%~dp0"
title Compilando Instalador Suporte Remoto...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
pause
endlocal
