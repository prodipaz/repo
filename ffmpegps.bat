@echo off
setlocal enabledelayedexpansion
title FFmpeg Auto Installer (Debug Safe Version)
echo ======================================================
echo           FFmpeg Auto Installer (Stable Build)
echo ======================================================
echo.

::-------------------------------------------------------
:: CONFIGURATION
::-------------------------------------------------------
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "FFMPEG_ZIP=%TEMP%\ffmpeg-release-essentials.zip"
set "INSTALL_DIR=C:\ffmpeg"
set "FFMPEG_BIN=%INSTALL_DIR%\bin"
set "PWSH_EXE=powershell.exe"
set "PWSH_PATH=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
set "TMP_PS1=%TEMP%\add_ffmpeg_to_path.ps1"

::-------------------------------------------------------
:: 1. ADMIN CHECK
::-------------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Please run this script as Administrator.
    pause
    exit /b
)

::-------------------------------------------------------
:: 2. CHECK POWERSHELL
::-------------------------------------------------------
echo [*] Checking PowerShell...
%PWSH_EXE% -Command "Write-Host 'PowerShell OK'" >nul 2>&1
if %errorlevel% neq 0 (
    if exist "%PWSH_PATH%" (
        echo [i] Found PowerShell at: %PWSH_PATH%
        set "PATH=%PATH%;C:\Windows\System32\WindowsPowerShell\v1.0"
        set "PWSH_EXE=%PWSH_PATH%"
    ) else (
        echo [X] PowerShell not found. Please install it first.
        pause
        exit /b
    )
)
echo [✓] PowerShell ready.
echo.

::-------------------------------------------------------
:: 3. DOWNLOAD FFMPEG
::-------------------------------------------------------
echo [1/5] Downloading FFmpeg stable build...
if exist "%FFMPEG_ZIP%" del "%FFMPEG_ZIP%" >nul 2>&1

"%PWSH_EXE%" -Command ^
    "Write-Host '  -> Downloading...';" ^
    "Invoke-WebRequest '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%' -UseBasicParsing;" ^
    "if (Test-Path '%FFMPEG_ZIP%') {Write-Host '  -> Download complete.'} else {Write-Host '  -> Download failed.'; exit 1}"

if %errorlevel% neq 0 (
    echo [X] Download failed. Check your internet connection.
    pause
    exit /b
)

::-------------------------------------------------------
:: 4. EXTRACT FFMPEG
::-------------------------------------------------------
echo [2/5] Extracting FFmpeg to %INSTALL_DIR% ...
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%"

"%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ^
    "Expand-Archive -Force -Path '%FFMPEG_ZIP%' -DestinationPath '%INSTALL_DIR%' ;" ^
    "Write-Host '  -> Extracted archive.'"

:: Handle unknown folder name (ffmpeg-*-essentials_build)
set "EXTRACTED_DIR="
for /d %%i in ("%INSTALL_DIR%\ffmpeg-*") do (
    set "EXTRACTED_DIR=%%i"
)

if defined EXTRACTED_DIR (
    echo [i] Moving contents from !EXTRACTED_DIR! ...
    xcopy "!EXTRACTED_DIR!\*" "%INSTALL_DIR%\" /e /i /h /y >nul
    rmdir /s /q "!EXTRACTED_DIR!"
) else (
    echo [!] Could not find extracted folder — check zip contents.
    pause
    exit /b
)

::-------------------------------------------------------
:: 5. ADD TO SYSTEM PATH (SAFE)
::-------------------------------------------------------
echo [3/5] Adding FFmpeg to system PATH...

set "ESC_BIN=%FFMPEG_BIN:\=\\%>"

> "%TMP_PS1%" (
    echo $ffpath = "%ESC_BIN%"
    echo $envPath = [Environment]::GetEnvironmentVariable('Path','Machine')
    echo if (-not ($envPath -match [regex]::Escape($ffpath))) {
    echo     [Environment]::SetEnvironmentVariable('Path', $envPath + ';' + $ffpath, 'Machine')
    echo     Write-Host "[✓] Added $ffpath to system PATH"
    echo } else {
    echo     Write-Host "[i] FFmpeg already in system PATH"
    echo }
)

"%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%TMP_PS1%"
del "%TMP_PS1%" >nul 2>&1

if %errorlevel% neq 0 (
    echo [!] Failed to modify system PATH.
    pause
    exit /b
)

::-------------------------------------------------------
:: 6. VERIFY INSTALLATION
::-------------------------------------------------------
echo.
echo [4/5] Verifying installation...
cmd /c "ffmpeg -version"
if %errorlevel% neq 0 (
    echo [!] FFmpeg not recognized yet. Try reopening Command Prompt or restarting your PC.
) else (
    echo [✓] FFmpeg successfully installed and added to PATH.
)

::-------------------------------------------------------
:: 7. CLEANUP
::-------------------------------------------------------
echo.
echo [5/5] Cleaning up...
del "%FFMPEG_ZIP%" >nul 2>&1

echo.
echo ======================================================
echo [DONE] FFmpeg installed successfully in: %INSTALL_DIR%
echo ======================================================
pause
exit /b
