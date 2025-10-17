@echo off
setlocal enabledelayedexpansion
title FFmpeg Auto Installer (Safe PATH Append)
echo ======================================================
echo              FFmpeg Auto Installer
echo ======================================================
echo.

::-------------------------------------------------------
:: CONFIGURATION
::-------------------------------------------------------
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "FFMPEG_ZIP=%TEMP%\ffmpeg-release-essentials.zip"
set "INSTALL_DIR=C:\ffmpeg"
set "FFMPEG_BIN=%INSTALL_DIR%\bin"

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
:: 2. CHECK EXISTING FFMPEG
::-------------------------------------------------------
where ffmpeg >nul 2>&1
if %errorlevel%==0 (
    for /f "delims=" %%v in ('ffmpeg -version 2^>nul ^| findstr /r "^ffmpeg"') do set "FFMPEG_VER=%%v"
    echo [i] Existing FFmpeg detected:
    echo     !FFMPEG_VER!
    echo.
    choice /m "Do you want to reinstall FFmpeg?"
    if errorlevel 2 (
        echo [✓] Keeping existing FFmpeg installation.
        pause
        exit /b
    )
)

::-------------------------------------------------------
:: 3. DOWNLOAD FFMPEG
::-------------------------------------------------------
echo [1/5] Downloading FFmpeg from %FFMPEG_URL% ...
powershell -Command "Invoke-WebRequest '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%'" || (
    echo [!] Download failed. Check your internet connection.
    pause
    exit /b
)

::-------------------------------------------------------
:: 4. EXTRACT TO C:\ffmpeg
::-------------------------------------------------------
echo [2/5] Extracting FFmpeg to %INSTALL_DIR% ...
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%"
powershell -Command "Expand-Archive -Force -Path '%FFMPEG_ZIP%' -DestinationPath '%INSTALL_DIR%'"

for /d %%i in ("%INSTALL_DIR%\ffmpeg-*") do set "EXTRACTED_DIR=%%i"
if defined EXTRACTED_DIR (
    xcopy "%EXTRACTED_DIR%\*" "%INSTALL_DIR%\" /e /i /h /y >nul
    rmdir /s /q "%EXTRACTED_DIR%"
)

::-------------------------------------------------------
:: 5. APPEND TO EXISTING SYSTEM PATH
::-------------------------------------------------------
echo [3/5] Adding C:\ffmpeg\bin to system PATH...

:: PowerShell safely appends FFmpeg to PATH without overwriting existing entries
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$path = [Environment]::GetEnvironmentVariable('Path','Machine');" ^
"if ($path -notmatch [regex]::Escape('%FFMPEG_BIN%')) {" ^
"    $newPath = $path + ';%FFMPEG_BIN%';" ^
"    [Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine');" ^
"    Write-Host '[✓] Successfully added %FFMPEG_BIN% to PATH';" ^
"} else {" ^
"    Write-Host '[i] %FFMPEG_BIN% already exists in PATH';" ^
"}"

if %errorlevel% neq 0 (
    echo [!] Failed to update system PATH.
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
    echo [!] FFmpeg not recognized yet. Please open a new Command Prompt or restart your PC.
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
echo [DONE] FFmpeg is installed at: %INSTALL_DIR%
echo It is added to your system PATH safely.
echo ======================================================
pause
exit /b
