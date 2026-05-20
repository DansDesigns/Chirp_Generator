@echo off
setlocal EnableDelayedExpansion
:: =============================================================================
::  Chirp Generator — Windows installer ^& launcher
::  Run once to install, then use the Start Menu shortcut or re-run to launch.
:: =============================================================================

title Chirp Generator Setup

:: ── Colours (via ANSI — works on Windows 10 1511+ / Windows 11) ──────────────
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "CYAN=%ESC%[36m"
set "GREEN=%ESC%[32m"
set "YELLOW=%ESC%[33m"
set "RED=%ESC%[31m"
set "BOLD=%ESC%[1m"
set "RESET=%ESC%[0m"

echo %BOLD%
echo   ===========================================
echo    Chirp Generator Setup  ^(Windows^)
echo   ===========================================
echo %RESET%

:: ── Paths ─────────────────────────────────────────────────────────────────────
set "SCRIPT_DIR=%~dp0"
:: Strip trailing backslash
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "APP_FILE=%SCRIPT_DIR%\chirp_generator.py"
set "VENV_DIR=%SCRIPT_DIR%\.venv"
set "VENV_PYTHON=%VENV_DIR%\Scripts\python.exe"
set "VENV_PIP=%VENV_DIR%\Scripts\pip.exe"

:: ── Sanity check ──────────────────────────────────────────────────────────────
if not exist "%APP_FILE%" (
    echo %RED%[ERROR]%RESET% chirp_generator.py not found in %SCRIPT_DIR%
    echo        Make sure this script is in the same folder as chirp_generator.py
    goto :fail
)

:: =============================================================================
:: 1. Find Python 3
:: =============================================================================
echo %CYAN%[INFO]%RESET%  Checking for Python 3...

set "PYTHON="

:: Try py launcher first (most reliable on Windows)
where py >nul 2>&1
if %errorlevel%==0 (
    for /F "tokens=*" %%v in ('py -3 --version 2^>^&1') do set "PYVER=%%v"
    set "PYTHON=py -3"
    echo %GREEN%[OK]%RESET%   Found Python via py launcher  ^(!PYVER!^)
    goto :python_found
)

:: Try plain python3 / python
for %%c in (python3 python) do (
    where %%c >nul 2>&1
    if !errorlevel!==0 (
        for /F "tokens=*" %%v in ('%%c --version 2^>^&1') do set "PYVER=%%v"
        echo !PYVER! | findstr /R "Python 3\." >nul
        if !errorlevel!==0 (
            set "PYTHON=%%c"
            echo %GREEN%[OK]%RESET%   Found !PYTHON!  ^(!PYVER!^)
            goto :python_found
        )
    )
)

:: Not found — guide the user
echo %RED%[ERROR]%RESET% Python 3 was not found on your PATH.
echo.
echo   Please install Python 3.9 or newer from:
echo     https://www.python.org/downloads/windows/
echo.
echo   IMPORTANT: On the installer's first page, tick
echo     "Add Python to PATH"  before clicking Install Now.
echo.
echo   Then re-run this script.
goto :fail

:python_found

:: =============================================================================
:: 2. Check / install tkinter (bundled with standard CPython on Windows)
:: =============================================================================
echo %CYAN%[INFO]%RESET%  Checking tkinter...
%PYTHON% -c "import tkinter" >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%[ERROR]%RESET% tkinter is not available.
    echo        Re-install Python from python.org and make sure the
    echo        "tcl/tk and IDLE" optional feature is selected.
    goto :fail
)
echo %GREEN%[OK]%RESET%   tkinter present

:: =============================================================================
:: 3. Check ffmpeg (optional — needed for MP3 export)
:: =============================================================================
echo %CYAN%[INFO]%RESET%  Checking ffmpeg...
where ffmpeg >nul 2>&1
if %errorlevel%==0 (
    for /F "tokens=3" %%v in ('ffmpeg -version 2^>^&1 ^| findstr /i "ffmpeg version"') do (
        echo %GREEN%[OK]%RESET%   ffmpeg %%v
        goto :ffmpeg_done
    )
    echo %GREEN%[OK]%RESET%   ffmpeg found
) else (
    echo %YELLOW%[WARN]%RESET% ffmpeg not found — MP3 export will be disabled.
    echo        To enable it, install ffmpeg and add it to your PATH:
    echo          https://ffmpeg.org/download.html
)
:ffmpeg_done

:: =============================================================================
:: 4. Virtual environment
:: =============================================================================
echo %CYAN%[INFO]%RESET%  Setting up virtual environment at %VENV_DIR%...

:: If venv exists but Scripts\python.exe is missing, wipe and recreate
if exist "%VENV_DIR%" (
    if not exist "%VENV_PYTHON%" (
        echo %YELLOW%[WARN]%RESET% Existing venv is broken — recreating...
        rmdir /S /Q "%VENV_DIR%"
    )
)

if not exist "%VENV_DIR%" (
    %PYTHON% -m venv "%VENV_DIR%"
    if %errorlevel% neq 0 (
        echo %RED%[ERROR]%RESET% Failed to create virtual environment.
        goto :fail
    )
    echo %GREEN%[OK]%RESET%   Virtual environment created
) else (
    echo %GREEN%[OK]%RESET%   Virtual environment already exists
)

if not exist "%VENV_PYTHON%" (
    echo %RED%[ERROR]%RESET% venv python not found at %VENV_PYTHON%
    goto :fail
)

:: =============================================================================
:: 5. Python dependencies
:: =============================================================================
echo %CYAN%[INFO]%RESET%  Upgrading pip...
"%VENV_PYTHON%" -m pip install --upgrade pip --quiet
if %errorlevel% neq 0 (
    echo %YELLOW%[WARN]%RESET% pip upgrade failed — continuing anyway
)

call :install_pkg numpy numpy
if %errorlevel% neq 0 goto :fail

call :install_pkg pydub pydub
if %errorlevel% neq 0 goto :fail

:: =============================================================================
:: 6. Start Menu shortcut
:: =============================================================================
echo %CYAN%[INFO]%RESET%  Creating Start Menu shortcut...

set "SM_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
set "SHORTCUT=%SM_DIR%\Chirp Generator.lnk"

:: Use PowerShell to create the .lnk (no extra tools needed)
powershell -NoProfile -Command ^
  "$s=(New-Object -COM WScript.Shell).CreateShortcut('%SHORTCUT%');" ^
  "$s.TargetPath='%VENV_PYTHON%';" ^
  "$s.Arguments='\""%APP_FILE%\"';" ^
  "$s.WorkingDirectory='%SCRIPT_DIR%';" ^
  "$s.Description='FM synthesis chirp sound designer';" ^
  "$s.Save()" >nul 2>&1

if %errorlevel%==0 (
    echo %GREEN%[OK]%RESET%   Shortcut created: %SHORTCUT%
) else (
    echo %YELLOW%[WARN]%RESET% Could not create Start Menu shortcut ^(non-fatal^)
)

:: =============================================================================
:: 7. Launch
:: =============================================================================
echo.
echo %GREEN%%BOLD%  All done!  Launching Chirp Generator...%RESET%
echo.

start "" "%VENV_PYTHON%" "%APP_FILE%"
goto :eof

:: =============================================================================
:: Helper: install a pip package if not already importable
:: Usage: call :install_pkg <pip-name> <import-name>
:: =============================================================================
:install_pkg
set "_pkg=%~1"
set "_imp=%~2"
"%VENV_PYTHON%" -c "import %_imp%" >nul 2>&1
if %errorlevel%==0 (
    echo %GREEN%[OK]%RESET%   %_pkg% already installed
    exit /B 0
)
echo %CYAN%[INFO]%RESET%  Installing %_pkg%...
"%VENV_PYTHON%" -m pip install "%_pkg%" --quiet
if %errorlevel% neq 0 (
    echo %RED%[ERROR]%RESET% Failed to install %_pkg% — cannot continue.
    exit /B 1
)
echo %GREEN%[OK]%RESET%   %_pkg% installed
exit /B 0

:: =============================================================================
:fail
echo.
echo %RED%%BOLD%  Setup failed. See messages above for details.%RESET%
echo.
pause
exit /B 1
