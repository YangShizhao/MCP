@echo off
REM ==============================================================================
REM MCP Offline Installer - Windows CMD Launcher
REM Run as Administrator to install MCP tools from the unified deps/ structure.
REM ==============================================================================

setlocal

set "SCRIPT_DIR=%~dp0"
set "PS1_SCRIPT=%SCRIPT_DIR%install.ps1"

where powershell.exe >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] PowerShell not found. This script requires PowerShell 5.1+.
    pause
    exit /b 1
)

echo.
echo ========================================
echo   MCP Offline Installer (Windows)
echo ========================================
echo.
echo Launching PowerShell install script...
echo.

REM -ExecutionPolicy Bypass: allow script execution
REM -NoProfile: skip user profile for faster startup
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%PS1_SCRIPT%" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Installation failed. See above for details.
    echo Try running as Administrator.
    pause
    exit /b 1
)

echo.
echo Press any key to close...
pause >nul
endlocal
exit /b 0
