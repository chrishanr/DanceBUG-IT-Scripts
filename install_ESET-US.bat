@echo off
:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

:: Run ESET-USINFIELD PowerShell script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ESET-USInfield.ps1"

#pause
