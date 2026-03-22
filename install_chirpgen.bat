@echo off
setlocal EnableDelayedExpansion
:: ─────────────────────────────────────────────────────────────────────────────
::  Chirp Generator — Windows installer & launcher
::  Run once to install, then double-click to launch.
::  Place this file in the same folder as chirp_generator.py
:: ─────────────────────────────────────────────────────────────────────────────

title Chirp Generator Setup

echo.
echo   +--------------------------------------+
echo   ^|       Chirp Generator Setup          ^|
echo   +--------------------------------------+
echo.

:: ── Paths ────────────────────────────────────────────────────────────────────
set "SCRIPT_DIR=%~dp0"
:: Strip trailing backslash
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "APP_FILE=%SCRIPT_DIR%\chirp_generator.py"
set "VENV_DIR=%SCRIPT_DIR%\.venv"
set "VENV_PYTHON=%VENV_DIR%\Scripts\python.exe"
set "VENV_PIP=%VENV_DIR%\Scripts\pip.exe"

:: ── Sanity check ─────────────────────────────────────────────────────────────
if not exist "%APP_FILE%" (
    echo [ERROR] chirp_generator.py not found in %SCRIPT_DIR%
    echo         Make sure this script is in the same folder as chirp_generator.py
    pause
    exit /b 1
)

:: ── 1. Python ────────────────────────────────────────────────────────────────
echo [....] Checking for Python 3...

set "PYTHON="
for %%C in (python python3 py) do (
    if "!PYTHON!"=="" (
        %%C --version >nul 2>&1
        if !errorlevel! == 0 (
            set "PYTHON=%%C"
        )
    )
)

:: Also check common install paths if not on PATH
if "!PYTHON!"=="" (
    for %%P in (
        "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python39\python.exe"
        "C:\Python312\python.exe"
        "C:\Python311\python.exe"
        "C:\Python310\python.exe"
    ) do (
        if "!PYTHON!"=="" (
            if exist %%P (
                set "PYTHON=%%~P"
            )
        )
    )
)

if "!PYTHON!"=="" (
    echo [WARN] Python 3 not found on PATH.
    echo.
    echo  Please install Python 3.9+ from https://www.python.org/downloads/
    echo  Make sure to tick "Add Python to PATH" during installation.
    echo.
    echo  Then re-run this script.
    pause
    exit /b 1
)

for /f "tokens=*" %%V in ('!PYTHON! -c "import sys; print(sys.version.split()[0])"') do set "PY_VER=%%V"
echo [ OK ] Found Python !PY_VER! at !PYTHON!

:: Verify tkinter is available (included in standard Python Windows installer)
!PYTHON! -c "import tkinter" >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] tkinter not found.
    echo         Re-install Python from python.org and ensure "tcl/tk and IDLE"
    echo         is checked in the optional features list.
    pause
    exit /b 1
)
echo [ OK ] tkinter OK

:: ── 2. ffmpeg ────────────────────────────────────────────────────────────────
echo [....] Checking for ffmpeg...

set "FFMPEG_OK=0"
ffmpeg -version >nul 2>&1
if !errorlevel! == 0 (
    set "FFMPEG_OK=1"
    echo [ OK ] ffmpeg found on PATH
)

if "!FFMPEG_OK!"=="0" (
    :: Try winget first (Windows 10 1709+ / Windows 11)
    winget --version >nul 2>&1
    if !errorlevel! == 0 (
        echo [....] Installing ffmpeg via winget...
        winget install --id Gyan.FFmpeg --silent --accept-package-agreements --accept-source-agreements
        if !errorlevel! == 0 (
            set "FFMPEG_OK=1"
            echo [ OK ] ffmpeg installed via winget
            echo [WARN] You may need to restart this script for ffmpeg to be on PATH.
        ) else (
            echo [WARN] winget install failed.
        )
    )
)

if "!FFMPEG_OK!"=="0" (
    :: Try chocolatey
    choco --version >nul 2>&1
    if !errorlevel! == 0 (
        echo [....] Installing ffmpeg via chocolatey...
        choco install ffmpeg -y
        if !errorlevel! == 0 (
            set "FFMPEG_OK=1"
            echo [ OK ] ffmpeg installed via chocolatey
        ) else (
            echo [WARN] chocolatey install failed.
        )
    )
)

if "!FFMPEG_OK!"=="0" (
    echo [WARN] Could not install ffmpeg automatically.
    echo        MP3 export will be disabled in the app.
    echo        To enable it later, download ffmpeg from https://ffmpeg.org/download.html
    echo        and add it to your PATH.
)

:: ── 3. Virtual environment ───────────────────────────────────────────────────
echo [....] Setting up virtual environment...

:: Detect broken venv
if exist "%VENV_DIR%" (
    if not exist "%VENV_PYTHON%" (
        echo [WARN] Existing venv is broken ^(missing python.exe^) — recreating...
        rmdir /s /q "%VENV_DIR%"
    )
)

if not exist "%VENV_DIR%" (
    echo [....] Creating virtual environment at %VENV_DIR%...
    !PYTHON! -m venv "%VENV_DIR%"
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to create virtual environment.
        pause
        exit /b 1
    )
    echo [ OK ] Virtual environment created
) else (
    echo [ OK ] Virtual environment already exists
)

if not exist "%VENV_PYTHON%" (
    echo [ERROR] venv python.exe not found at %VENV_PYTHON%
    pause
    exit /b 1
)
if not exist "%VENV_PIP%" (
    echo [ERROR] venv pip.exe not found at %VENV_PIP%
    pause
    exit /b 1
)

:: ── 4. Python dependencies ───────────────────────────────────────────────────
echo [....] Checking Python dependencies...

echo [....] Upgrading pip...
"%VENV_PIP%" install --upgrade pip >nul 2>&1
if !errorlevel! neq 0 (
    echo [WARN] pip upgrade failed — continuing anyway
)

call :install_required numpy
call :install_required pydub

echo [ OK ] Python dependencies OK

:: ── 5. Desktop shortcut ──────────────────────────────────────────────────────
echo [....] Creating desktop shortcut...

set "SHORTCUT=%USERPROFILE%\Desktop\Chirp Generator.lnk"
set "VENV_PYTHONW=%VENV_DIR%\Scripts\pythonw.exe"

:: Use pythonw.exe (no console window) if available, else python.exe
if not exist "%VENV_PYTHONW%" set "VENV_PYTHONW=%VENV_PYTHON%"

:: Create shortcut using PowerShell
powershell -NoProfile -Command ^
  "$ws = New-Object -ComObject WScript.Shell; ^
   $sc = $ws.CreateShortcut('%SHORTCUT%'); ^
   $sc.TargetPath = '%VENV_PYTHONW%'; ^
   $sc.Arguments = '\"%APP_FILE%\"'; ^
   $sc.WorkingDirectory = '%SCRIPT_DIR%'; ^
   $sc.Description = 'Chirp Generator - FM Synthesis Sound Designer'; ^
   $sc.Save()" >nul 2>&1

if exist "%SHORTCUT%" (
    echo [ OK ] Desktop shortcut created: %SHORTCUT%
) else (
    echo [WARN] Could not create desktop shortcut ^(PowerShell may be restricted^).
    echo        You can launch the app by running this batch file directly.
)

:: ── Done ─────────────────────────────────────────────────────────────────────
echo.
echo   All done! Launching Chirp Generator...
echo.

:: ── 6. Launch ────────────────────────────────────────────────────────────────
:: Use pythonw.exe to launch without a console window
if exist "%VENV_PYTHONW%" (
    start "" "%VENV_PYTHONW%" "%APP_FILE%"
) else (
    start "" "%VENV_PYTHON%" "%APP_FILE%"
)
exit /b 0


:: ─────────────────────────────────────────────────────────────────────────────
::  Subroutine: install_required <package_name> [import_name]
:: ─────────────────────────────────────────────────────────────────────────────
:install_required
set "PKG=%~1"
set "IMP=%~1"
if not "%~2"=="" set "IMP=%~2"

"%VENV_PYTHON%" -c "import !IMP!" >nul 2>&1
if !errorlevel! == 0 (
    echo [ OK ] !PKG! already installed
    goto :eof
)

echo [....] Installing !PKG!...
"%VENV_PIP%" install "!PKG!"
if !errorlevel! neq 0 (
    echo [ERROR] Failed to install !PKG! — cannot continue.
    pause
    exit /b 1
)
echo [ OK ] !PKG! installed
goto :eof
