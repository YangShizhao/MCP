@echo off
REM ==============================================================================
REM MCP Offline Pack Script - Windows CMD Launcher
REM
REM Default: packs ALL tools (PDF + Office) + ALL runtimes (Node.js + Python).
REM Use --skip-* to exclude specific components.
REM
REM Options:
REM   --skip-nodejs      Skip Node.js portable runtime
REM   --skip-python      Skip Python embedded runtime
REM   --skip-pdf         Skip PDF tools
REM   --skip-office      Skip Office tools (Word/PPT/Excel)
REM   --no-cache         Ignore cache, force re-download
REM   --help, -h         Show this help
REM
REM Examples:
REM   pack.cmd                                    Pack everything (default)
REM   pack.cmd --skip-office --skip-python        PDF tools only
REM   pack.cmd --skip-pdf --skip-nodejs           Office tools only
REM   pack.cmd --skip-nodejs --skip-python        Skip runtimes
REM
REM Tip: From PowerShell, you can run ".\pack.ps1" directly.
REM ==============================================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PS1_SCRIPT=%SCRIPT_DIR%pack.ps1"

where powershell.exe >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] PowerShell not found. This script requires PowerShell 5.1+.
    exit /b 1
)

if "%~1"=="--help" goto :show_help
if "%~1"=="-h" goto :show_help

set "PS_ARGS="

:parse_args
if "%~1"=="" goto :run
if "%~1"=="--skip-nodejs"  ( set "PS_ARGS=!PS_ARGS! -SkipNodejs"  & shift & goto :parse_args )
if "%~1"=="--skip-python"  ( set "PS_ARGS=!PS_ARGS! -SkipPython"  & shift & goto :parse_args )
if "%~1"=="--skip-pdf"     ( set "PS_ARGS=!PS_ARGS! -SkipPdf"     & shift & goto :parse_args )
if "%~1"=="--skip-office"  ( set "PS_ARGS=!PS_ARGS! -SkipOffice"  & shift & goto :parse_args )
if "%~1"=="--no-cache"     ( set "PS_ARGS=!PS_ARGS! -NoCache"     & shift & goto :parse_args )
if "%~1"=="--refresh"      ( set "PS_ARGS=!PS_ARGS! -NoCache"     & shift & goto :parse_args )
REM Forward unknown args as-is
set "PS_ARGS=!PS_ARGS! %~1"
shift
goto :parse_args

:run
echo.
echo ========================================
echo   MCP Offline Pack Tool (Windows)
echo ========================================
echo.
echo Launching PowerShell pack script...
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%PS1_SCRIPT%" %PS_ARGS%

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Pack failed. See output above for details.
    echo If you see "cannot be loaded", run this script as Administrator.
    pause
    exit /b 1
)

echo.
echo Press any key to close...
pause >nul
endlocal
exit /b 0

:show_help
echo.
echo MCP Offline Pack Script - Windows CMD Launcher
echo.
echo Default: packs ALL tools (PDF + Office) + ALL runtimes (Node.js + Python).
echo Use --skip-* to exclude specific components.
echo.
echo Usage: pack.cmd [options]
echo.
echo Options:
echo   --skip-nodejs      Skip Node.js portable runtime (~30 MB)
echo   --skip-python      Skip Python embedded runtime (~15 MB)
echo   --skip-pdf         Skip PDF tools (pdf-reader-mcp + pdf-toolkit-mcp)
echo   --skip-office      Skip Office tools (wordmcp + pptmcp + excelmcp)
echo   --no-cache         Ignore cache, force re-download
echo   --refresh          Same as --no-cache
echo   --help, -h         Show this help
echo.
echo Examples:
echo   pack.cmd                                    Pack everything (default)
echo   pack.cmd --skip-office --skip-python        PDF tools only
echo   pack.cmd --skip-pdf --skip-nodejs           Office tools only
echo   pack.cmd --skip-nodejs --skip-python        No bundled runtimes
echo   pack.cmd --no-cache                         Force refresh all
echo.
echo Output: build\mcp-offline-win-YYYYMMDD.zip
echo.
echo Tip: From PowerShell, you can run ".\pack.ps1" directly with the same parameters.
echo      e.g.:  .\pack.ps1 -SkipOffice -SkipPython
echo.
echo.
echo Press any key to close...
pause >nul
endlocal
exit /b 0
