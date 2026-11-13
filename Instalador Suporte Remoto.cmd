@echo off
setlocal
cd /d "%~dp0"
title Instalador Suporte Remoto

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0config.ps1"

endlocal
