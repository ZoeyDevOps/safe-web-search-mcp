@echo off
REM SPDX-License-Identifier: MIT
REM Copyright (c) 2026 Zoey and contributors
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0scripts\setup-lm-studio.ps1"
set "SafeWebSearchExitCode=%ERRORLEVEL%"
if not "%SafeWebSearchExitCode%"=="0" (
    echo.
    echo Safe Web Search MCP setup failed. Read the error above; no existing LM Studio configuration was overwritten.
    pause
)
endlocal & exit /b %SafeWebSearchExitCode%
